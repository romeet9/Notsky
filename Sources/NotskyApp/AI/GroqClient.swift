import Foundation

// MARK: - Wire types (Sendable, so they cross the main-actor / network boundary safely)

struct AIToolCall: Sendable, Equatable {
    var id: String
    var name: String
    var arguments: String
}

struct AIMessage: Sendable {
    var role: String            // system | user | assistant | tool
    var content: String?
    var toolCalls: [AIToolCall] = []
    var toolCallID: String? = nil
    var name: String? = nil

    static func system(_ text: String) -> AIMessage { AIMessage(role: "system", content: text) }
    static func user(_ text: String) -> AIMessage { AIMessage(role: "user", content: text) }
    static func assistant(_ text: String) -> AIMessage { AIMessage(role: "assistant", content: text) }
    static func tool(id: String, name: String, content: String) -> AIMessage {
        AIMessage(role: "tool", content: content, toolCallID: id, name: name)
    }

    var json: [String: Any] {
        var dict: [String: Any] = ["role": role]
        if let content, !content.isEmpty {
            dict["content"] = content
        } else if role == "assistant" && !toolCalls.isEmpty {
            dict["content"] = NSNull()
        } else {
            dict["content"] = content ?? ""
        }
        if !toolCalls.isEmpty {
            dict["tool_calls"] = toolCalls.map { call in
                ["id": call.id, "type": "function", "function": ["name": call.name, "arguments": call.arguments]] as [String: Any]
            }
        }
        if let toolCallID { dict["tool_call_id"] = toolCallID }
        if let name, role == "tool" { dict["name"] = name }
        return dict
    }
}

struct AIReply: Sendable {
    var content: String?
    var toolCalls: [AIToolCall]
}

// MARK: - Errors

enum GroqError: LocalizedError, Sendable, Equatable {
    case notConnected
    case unauthorized
    case rateLimited(retryAfter: Int?)
    case offline
    case timedOut
    case modelUnavailable
    case malformedAction
    case server(code: Int, message: String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return String(localized: "Add your Groq API key in Settings › AI first.")
        case .unauthorized:
            return String(localized: "Groq didn't accept that API key. Check it in Settings › AI.")
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return String(localized: "Groq is rate limiting requests. Try again in \(retryAfter) seconds.")
            }
            return String(localized: "Groq is rate limiting requests. Try again in a moment.")
        case .offline:
            return String(localized: "You appear to be offline. Check your connection and try again.")
        case .timedOut:
            return String(localized: "Groq took too long to answer. Try again.")
        case .modelUnavailable:
            return String(localized: "That model isn't available right now. Pick another in Settings › AI.")
        case .malformedAction:
            return String(localized: "The model sent a malformed action. Try rephrasing.")
        case .server(let code, let message):
            return message.isEmpty
                ? String(localized: "Groq returned an error (\(code)).")
                : String(localized: "Groq returned an error (\(code)): \(message)")
        case .badResponse:
            return String(localized: "Groq sent back something unexpected. Try again.")
        }
    }
}

// MARK: - Client

/// OpenAI-compatible Groq endpoints. Pure network code: runs off the main actor, never logs the key.
enum GroqClient {
    static let baseURL = URL(string: "https://api.groq.com/openai/v1")!

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static let preferredModels = [
        "openai/gpt-oss-120b",
        "moonshotai/kimi-k2-instruct-0905",
        "moonshotai/kimi-k2-instruct",
        "llama-3.3-70b-versatile"
    ]

    /// Chat-capable model ids (speech, guard and TTS models removed), sorted.
    static func listModels(key: String) async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let data = try await send(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["data"] as? [[String: Any]] else { throw GroqError.badResponse }
        let ids = list.compactMap { $0["id"] as? String }
        let chat = ids.filter { id in
            let lower = id.lowercased()
            return !["whisper", "guard", "tts", "orpheus", "playai"].contains { lower.contains($0) }
        }
        return chat.sorted()
    }

    static func defaultModel(from models: [String]) -> String? {
        preferredModels.first(where: models.contains) ?? models.first
    }

    /// One non-streaming chat completion, optionally with tools (JSON array of tool definitions).
    static func chat(key: String, model: String, messages: [AIMessage], tools: Data?) async throws -> AIReply {
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map(\.json),
            "temperature": 0.3,
            // Tool-call arguments (e.g. note text) need room; the reply itself stays short via the prompt.
            "max_tokens": tools == nil ? 120 : 400
        ]
        if let tools, let parsed = try? JSONSerialization.jsonObject(with: tools) as? [[String: Any]], !parsed.isEmpty {
            body["tools"] = parsed
            body["tool_choice"] = "auto"
        }
        if model.lowercased().contains("gpt-oss") { body["reasoning_effort"] = "low" }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choice = (json["choices"] as? [[String: Any]])?.first,
              let message = choice["message"] as? [String: Any] else { throw GroqError.badResponse }
        let content = message["content"] as? String
        let calls: [AIToolCall] = ((message["tool_calls"] as? [[String: Any]]) ?? []).compactMap { raw in
            guard let fn = raw["function"] as? [String: Any], let name = fn["name"] as? String else { return nil }
            let id = (raw["id"] as? String) ?? UUID().uuidString
            return AIToolCall(id: id, name: name, arguments: (fn["arguments"] as? String) ?? "{}")
        }
        return AIReply(content: content, toolCalls: calls)
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GroqError.badResponse }
            switch http.statusCode {
            case 200..<300:
                return data
            case 401, 403:
                throw GroqError.unauthorized
            case 429:
                let retry = http.value(forHTTPHeaderField: "retry-after").flatMap { Double($0) }.map { Int($0.rounded(.up)) }
                throw GroqError.rateLimited(retryAfter: retry)
            case 404:
                throw GroqError.modelUnavailable
            default:
                let (code, message) = errorDetails(from: data)
                if code == "tool_use_failed" { throw GroqError.malformedAction }
                if code == "model_decommissioned" || code == "model_not_found" { throw GroqError.modelUnavailable }
                throw GroqError.server(code: http.statusCode, message: String(message.prefix(160)))
            }
        } catch let error as GroqError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotFindHost, .cannotConnectToHost:
                throw GroqError.offline
            case .timedOut:
                throw GroqError.timedOut
            case .cancelled:
                throw CancellationError()
            default:
                throw GroqError.server(code: error.errorCode, message: error.localizedDescription)
            }
        }
    }

    private static func errorDetails(from data: Data) -> (code: String, message: String) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = json["error"] as? [String: Any] else { return ("", "") }
        return ((err["code"] as? String) ?? "", (err["message"] as? String) ?? "")
    }
}

// MARK: - Account (key, models, preferences)

/// Observable Groq connection state. The key lives in the Keychain and is never logged or persisted elsewhere.
@MainActor
@Observable
final class GroqAccount {
    static let shared = GroqAccount()

    private static let keychainAccount = "notsky_groq_api_key"
    private static let modelKey = "notsky.groq.model"
    private static let searchKey = "notsky.ai.searchFiles"

    private(set) var hasKey: Bool
    private(set) var models: [String] = []
    private(set) var connectError: String?
    private(set) var isLoadingModels = false

    var selectedModel: String? {
        didSet { UserDefaults.standard.set(selectedModel, forKey: Self.modelKey) }
    }

    var searchFilesEnabled: Bool {
        didSet { UserDefaults.standard.set(searchFilesEnabled, forKey: Self.searchKey) }
    }

    @ObservationIgnored private var cachedKey: String?

    private init() {
        let stored = KeychainHelper.shared.string(forKey: Self.keychainAccount)
        cachedKey = (stored?.isEmpty == false) ? stored : nil
        hasKey = cachedKey != nil
        selectedModel = UserDefaults.standard.string(forKey: Self.modelKey)
        searchFilesEnabled = (UserDefaults.standard.object(forKey: Self.searchKey) as? Bool) ?? true
    }

    func currentKey() -> String? { cachedKey }

    /// The model picker value: the saved choice if still offered, else the best default.
    var activeModel: String {
        if let selectedModel, models.isEmpty || models.contains(selectedModel) { return selectedModel }
        return GroqClient.defaultModel(from: models) ?? GroqClient.preferredModels[0]
    }

    /// Validates the key against /models, then stores it in the Keychain.
    @discardableResult
    func connect(key raw: String) async -> Bool {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        connectError = nil
        do {
            let list = try await GroqClient.listModels(key: key)
            guard !list.isEmpty else {
                connectError = String(localized: "That key works, but no chat models were returned.")
                return false
            }
            KeychainHelper.shared.setString(key, forKey: Self.keychainAccount)
            cachedKey = key
            models = list
            if let selectedModel, !list.contains(selectedModel) { self.selectedModel = nil }
            hasKey = true
            return true
        } catch {
            connectError = error.localizedDescription
            return false
        }
    }

    func disconnect() {
        KeychainHelper.shared.delete(key: Self.keychainAccount)
        cachedKey = nil
        hasKey = false
        models = []
        connectError = nil
    }

    func refreshModels() async {
        guard let key = cachedKey, !isLoadingModels else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }
        do {
            let list = try await GroqClient.listModels(key: key)
            models = list
            if let selectedModel, !list.contains(selectedModel) { self.selectedModel = nil }
        } catch GroqError.unauthorized {
            connectError = GroqError.unauthorized.localizedDescription
        } catch {
            // Keep whatever list we had; the agent will surface real errors when it sends a request.
        }
    }

    func ensureModelsLoaded() async {
        if models.isEmpty { await refreshModels() }
    }
}
