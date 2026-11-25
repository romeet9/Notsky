import Foundation
import AppKit
import Observation

// MARK: - Models

public struct LinearWorkflowState: Codable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var type: String
    public var color: String
    public var position: Double?
}

public struct LinearTeam: Codable, Hashable, Identifiable {
    public var id: String
    public var key: String
    public var name: String
    public var color: String?
    public var states: LinearNodes<LinearWorkflowState>?
}

public struct LinearNodes<T: Codable & Hashable>: Codable, Hashable {
    public var nodes: [T]
}

public struct LinearCycle: Codable, Hashable {
    public var number: Double?
}

public struct LinearIssue: Codable, Hashable, Identifiable {
    public var id: String
    public var identifier: String
    public var title: String
    public var url: String
    public var priority: Int
    public var priorityLabel: String?
    public var dueDate: String?
    public var completedAt: String?
    public var updatedAt: String?
    public var state: LinearWorkflowState
    public var team: LinearTeam
    public var cycle: LinearCycle?

    /// Team workflow states sorted by position.
    public var teamStates: [LinearWorkflowState] {
        (team.states?.nodes ?? []).sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    public var isOverdue: Bool {
        guard let due = LinearService.parseDate(dueDate) else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }
}

public struct LinearViewer: Codable, Hashable {
    public var id: String
    public var name: String
}

public enum LinearError: Error, Equatable {
    case notConnected
    case unauthorized
    case rateLimited
    case offline
    case message(String)

    var userMessage: String {
        switch self {
        case .notConnected: return "Linear is not connected."
        case .unauthorized: return "Linear key was rejected. Reconnect Linear."
        case .rateLimited: return "Linear rate limit reached. Retrying soon."
        case .offline: return "You appear to be offline."
        case .message(let m): return m
        }
    }
}

public enum LinearStatus: Equatable {
    case notConnected
    case loading
    case ready
    case unauthorized
    case rateLimited
    case offline
    case failed(String)
}

// MARK: - Service

/// Single shared Linear service. It polls only while at least one Linear card exists and is visible.
@MainActor
@Observable
public final class LinearService {
    public static let shared = LinearService()

    private static let keychainKey = "notsky_linear_api_key"
    private static let endpoint = URL(string: "https://api.linear.app/graphql")!

    public private(set) var issues: [LinearIssue] = []
    public private(set) var viewer: LinearViewer? = nil
    public private(set) var teams: [LinearTeam] = []
    public private(set) var status: LinearStatus = .notConnected
    public private(set) var isRefreshing = false
    public private(set) var lastUpdated: Date? = nil
    public private(set) var hasKey = false
    public var toast: String? = nil
    public private(set) var connectError: String? = nil

    @ObservationIgnored private var apiKey: String? = nil
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var visibleViewCount = 0
    @ObservationIgnored private var pollTask: Task<Void, Never>? = nil
    @ObservationIgnored private var toastTask: Task<Void, Never>? = nil
    @ObservationIgnored private var failureCount = 0
    @ObservationIgnored private var mutationsInFlight = 0
    @ObservationIgnored private var refreshGeneration = 0

    private init() {
        if let stored = KeychainHelper.shared.string(forKey: Self.keychainKey), !stored.isEmpty {
            apiKey = stored
            hasKey = true
        }
    }

    // MARK: Lifecycle

    public func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            status = hasKey ? .loading : .notConnected
            startPolling()
        } else {
            stopPolling()
        }
    }

    public func viewDidAppear() {
        visibleViewCount += 1
        refresh()
    }

    public func viewDidDisappear() {
        visibleViewCount = max(0, visibleViewCount - 1)
    }

    private func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = self.nextPollDelay()
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { return }
                if self.visibleViewCount > 0, self.status != .unauthorized {
                    await self.performRefresh()
                }
            }
        }
        refresh()
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// 60s normally; exponential backoff (capped at 15 min) while failing.
    private func nextPollDelay() -> TimeInterval {
        guard failureCount > 0 else { return 60 }
        return min(900, 30 * pow(2, Double(min(failureCount, 6))))
    }

    // MARK: Auth

    public var connectedName: String? { hasKey ? viewer?.name : nil }

    /// Validates and stores a personal API key. Returns true when connected.
    @discardableResult
    public func connect(key rawKey: String) async -> Bool {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        connectError = nil
        do {
            let data: ViewerOnly = try await Self.send(query: Self.viewerQuery, variables: nil, key: key)
            KeychainHelper.shared.setString(key, forKey: Self.keychainKey)
            apiKey = key
            hasKey = true
            viewer = data.viewer
            failureCount = 0
            status = .loading
            if isActive { refresh() }
            return true
        } catch let error as LinearError {
            connectError = error.userMessage
            return false
        } catch {
            connectError = "Could not reach Linear."
            return false
        }
    }

    public func disconnect() {
        KeychainHelper.shared.delete(key: Self.keychainKey)
        apiKey = nil
        hasKey = false
        viewer = nil
        issues = []
        teams = []
        connectError = nil
        failureCount = 0
        status = .notConnected
    }

    // MARK: Fetch

    public func refresh() {
        Task { await performRefresh() }
    }

    private func performRefresh() async {
        guard let key = apiKey else {
            status = .notConnected
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshGeneration += 1
        let generation = refreshGeneration
        if issues.isEmpty { status = .loading }
        defer { isRefreshing = false }
        do {
            let data: ViewerIssues = try await Self.send(query: Self.issuesQuery(), variables: nil, key: key)
            guard generation == refreshGeneration, mutationsInFlight == 0, apiKey == key else { return }
            viewer = LinearViewer(id: data.viewer.id, name: data.viewer.name)
            teams = data.viewer.teams?.nodes ?? []
            let done = (data.viewer.doneIssues?.nodes ?? []).sorted { ($0.completedAt ?? "") > ($1.completedAt ?? "") }
            // Workflow states are fetched once per team (keeps the query under Linear's complexity limit)
            // and attached to each issue's team here.
            let statesByTeam = Dictionary(teams.map { ($0.id, $0.states) }, uniquingKeysWith: { a, _ in a })
            issues = (data.viewer.assignedIssues.nodes + done).map { issue in
                var copy = issue
                if copy.team.states == nil, let states = statesByTeam[copy.team.id] { copy.team.states = states }
                return copy
            }
            failureCount = 0
            lastUpdated = Date()
            status = .ready
        } catch let error as LinearError {
            apply(error)
        } catch {
            failureCount += 1
            status = .failed("Something went wrong.")
        }
    }

    private func apply(_ error: LinearError) {
        switch error {
        case .unauthorized:
            status = .unauthorized
        case .rateLimited:
            failureCount += 1
            status = .rateLimited
        case .offline:
            failureCount += 1
            status = .offline
        case .notConnected:
            status = .notConnected
        case .message(let m):
            failureCount += 1
            status = .failed(m)
        }
    }

    // MARK: Mutations

    public func setState(_ state: LinearWorkflowState, for issue: LinearIssue) {
        guard issue.state.id != state.id, let key = apiKey, let index = issues.firstIndex(where: { $0.id == issue.id }) else { return }
        let original = issues[index]
        var updated = original
        updated.state = state
        if state.type == "canceled" {
            issues.remove(at: index)
        } else {
            if state.type == "completed" { updated.completedAt = ISO8601DateFormatter().string(from: Date()) }
            issues[index] = updated
        }
        runMutation(
            key: key,
            input: ["stateId": state.id],
            issueId: issue.id,
            rollback: { [weak self] in self?.restore(original, at: index) },
            confirm: { [weak self] result in
                guard let self, let i = self.issues.firstIndex(where: { $0.id == issue.id }) else { return }
                self.issues[i].state = result.state
            }
        )
    }

    public func setPriority(_ priority: Int, for issue: LinearIssue) {
        guard issue.priority != priority, let key = apiKey, let index = issues.firstIndex(where: { $0.id == issue.id }) else { return }
        let original = issues[index]
        issues[index].priority = priority
        runMutation(
            key: key,
            input: ["priority": priority],
            issueId: issue.id,
            rollback: { [weak self] in self?.restore(original, at: index) },
            confirm: { [weak self] result in
                guard let self, let i = self.issues.firstIndex(where: { $0.id == issue.id }) else { return }
                self.issues[i].priority = result.priority
                self.issues[i].priorityLabel = result.priorityLabel
            }
        )
    }

    /// Sets (or clears, with nil) an issue's due date. `day` is "yyyy-MM-dd".
    public func setDueDate(_ day: String?, for issue: LinearIssue) {
        guard issue.dueDate != day, let key = apiKey, let index = issues.firstIndex(where: { $0.id == issue.id }) else { return }
        let original = issues[index]
        issues[index].dueDate = day
        let value: Any = day.map { $0 as Any } ?? NSNull()
        runMutation(
            key: key,
            input: ["dueDate": value],
            issueId: issue.id,
            rollback: { [weak self] in self?.restore(original, at: index) },
            confirm: { [weak self] result in
                guard let self, let i = self.issues.firstIndex(where: { $0.id == issue.id }) else { return }
                self.issues[i].dueDate = result.dueDate
            }
        )
    }

    private func restore(_ original: LinearIssue, at index: Int) {
        if let i = issues.firstIndex(where: { $0.id == original.id }) {
            issues[i] = original
        } else {
            issues.insert(original, at: min(index, issues.count))
        }
    }

    private func runMutation(
        key: String,
        input: [String: Any],
        issueId: String,
        rollback: @escaping () -> Void,
        confirm: @escaping (IssueUpdateResult) -> Void
    ) {
        mutationsInFlight += 1
        Task {
            defer { mutationsInFlight -= 1 }
            do {
                let data: IssueUpdateData = try await Self.send(
                    query: Self.updateMutation,
                    variables: ["id": issueId, "input": input],
                    key: key
                )
                guard data.issueUpdate.success, let issue = data.issueUpdate.issue else { throw LinearError.message("Linear did not accept the change.") }
                confirm(issue)
            } catch let error as LinearError {
                rollback()
                if error == .unauthorized { status = .unauthorized }
                showToast("Couldn't update issue. " + error.userMessage)
            } catch {
                rollback()
                showToast("Couldn't update issue.")
            }
        }
    }

    /// Creates an issue assigned to the viewer, then refreshes. Returns true on success.
    @discardableResult
    public func createIssue(title: String, teamId: String, dueDate: String? = nil) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let key = apiKey, let viewerId = viewer?.id else { return false }
        var input: [String: Any] = ["teamId": teamId, "title": trimmed, "assigneeId": viewerId]
        if let dueDate { input["dueDate"] = dueDate }
        do {
            let data: IssueCreateData = try await Self.send(
                query: Self.createMutation,
                variables: ["input": input],
                key: key
            )
            guard data.issueCreate.success else { throw LinearError.message("Linear did not create the issue.") }
            await performRefresh()
            return true
        } catch let error as LinearError {
            showToast("Couldn't create issue. " + error.userMessage)
            return false
        } catch {
            showToast("Couldn't create issue.")
            return false
        }
    }

    // MARK: Actions

    public func open(_ issue: LinearIssue) {
        guard let https = URL(string: issue.url) else { return }
        var target = https
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.linear") != nil,
           issue.url.hasPrefix("https://linear.app/"),
           let native = URL(string: issue.url.replacingOccurrences(of: "https://linear.app/", with: "linear://")) {
            target = native
        }
        NSWorkspace.shared.open(target)
    }

    public func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    public func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    // MARK: Helpers

    public nonisolated static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)
    }

    /// Formats a local calendar day as Linear's "yyyy-MM-dd" TimelessDate.
    public nonisolated static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: GraphQL

    private static let issueFields = """
    id identifier title url priority priorityLabel dueDate completedAt updatedAt
    state { id name type color }
    team { id key name color }
    cycle { number }
    """

    private static let viewerQuery = "query { viewer { id name } }"

    private static func issuesQuery() -> String {
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-14 * 86_400))
        return """
    query {
      viewer {
        id name
        teams(first: 50) { nodes { id key name color states(first: 50) { nodes { id name type color position } } } }
        assignedIssues(filter: {state: {type: {nin: ["completed","canceled"]}}}, first: 75, orderBy: updatedAt) {
          nodes { \(issueFields) }
        }
        doneIssues: assignedIssues(filter: {state: {type: {eq: "completed"}}, completedAt: {gt: "\(cutoff)"}}, first: 50, orderBy: updatedAt) {
          nodes { \(issueFields) }
        }
      }
    }
    """
    }

    private static let updateMutation = """
    mutation($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue { id state { id name type color } priority priorityLabel dueDate }
      }
    }
    """

    private static let createMutation = """
    mutation($input: IssueCreateInput!) {
      issueCreate(input: $input) { success issue { id } }
    }
    """

    private struct ViewerOnly: Decodable { let viewer: LinearViewer }
    private struct ViewerIssues: Decodable {
        struct V: Decodable {
            let id: String
            let name: String
            let teams: LinearNodes<LinearTeam>?
            let assignedIssues: LinearNodes<LinearIssue>
            let doneIssues: LinearNodes<LinearIssue>?
        }
        let viewer: V
    }
    struct IssueUpdateResult: Decodable {
        let id: String
        let state: LinearWorkflowState
        let priority: Int
        let priorityLabel: String?
        let dueDate: String?
    }
    private struct IssueUpdateData: Decodable {
        struct P: Decodable { let success: Bool; let issue: IssueUpdateResult? }
        let issueUpdate: P
    }
    private struct IssueCreateData: Decodable {
        struct P: Decodable { let success: Bool }
        let issueCreate: P
    }
    private struct GraphQLEnvelope<D: Decodable>: Decodable {
        struct E: Decodable {
            struct Ext: Decodable { let code: String?; let type: String? }
            let message: String
            let extensions: Ext?
        }
        let data: D?
        let errors: [E]?
    }

    /// Runs off the main actor. Never logs the key.
    private nonisolated static func send<D: Decodable>(query: String, variables: [String: Any]?, key: String) async throws -> D {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["query": query]
        if let variables { body["variables"] = variables }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed:
                throw LinearError.offline
            default:
                throw LinearError.message("Network error.")
            }
        }

        let http = response as? HTTPURLResponse
        let envelope = try? JSONDecoder().decode(GraphQLEnvelope<D>.self, from: data)
        if http?.statusCode == 401 { throw LinearError.unauthorized }
        if http?.statusCode == 429 { throw LinearError.rateLimited }
        if let errors = envelope?.errors, !errors.isEmpty {
            let codes = errors.compactMap { ($0.extensions?.code ?? $0.extensions?.type)?.uppercased() }
            if codes.contains(where: { $0.contains("RATELIMIT") }) { throw LinearError.rateLimited }
            if codes.contains(where: { $0.contains("AUTHENTICATION") || $0.contains("UNAUTHENTICATED") }) { throw LinearError.unauthorized }
            throw LinearError.message(errors.first?.message ?? "Linear returned an error.")
        }
        guard let value = envelope?.data else {
            if let code = http?.statusCode, code >= 400 { throw LinearError.message("Linear returned HTTP \(code).") }
            throw LinearError.message("Unexpected response from Linear.")
        }
        return value
    }
}
