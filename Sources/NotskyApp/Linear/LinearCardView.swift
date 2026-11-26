import SwiftUI
import AppKit

/// Linear card as a collapsible list (To Do / In Progress / Done), sized like the notes card (586 x 364).
@MainActor
public struct LinearCardView: View {
    @Binding public var note: NoteCard
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var onSpawnWidget: () -> Void = {}
    public var onDelete: () -> Void = {}

    private var service = LinearService.shared
    private var settings: AppSettings { AppSettings.shared }

    @State private var isHoveringRefresh = false

    private var cardWidth: CGFloat { CGFloat(note.width) }
    private var cardHeight: CGFloat { CGFloat(note.height) }
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40

    private var isDark: Bool {
        if let override = settings.preferredColorScheme { return override == .dark }
        return colorScheme == .dark
    }

    private var sheetBackgroundColor: Color {
        let opacity = settings.backgroundOpacity
        return isDark ? Color(white: 0.12).opacity(opacity) : Color.white.opacity(opacity)
    }

    private func buttonBackgroundColor(hovering: Bool) -> Color {
        WidgetCardDesign.buttonBackgroundColor(isDark: isDark, hovering: hovering, baseOpacity: settings.backgroundOpacity)
    }

    private var specularBorderGradient: LinearGradient { WidgetCardDesign.specularBorder(isDark: isDark) }
    private var primaryText: Color { isDark ? .white : .black }
    private var secondaryText: Color { isDark ? .white.opacity(0.6) : .black.opacity(0.5) }
    private var tertiaryText: Color { isDark ? .white.opacity(0.4) : .black.opacity(0.35) }
    private var accent: Color { ImageLuminanceDetector.dominantAccentColor(at: note.headerImagePath) }
    private static let linearIndigo = "#5E6AD2"

    @AppStorage("linear.tab") private var storedTab = ""

    fileprivate enum Section: Int, CaseIterable {
        case todo, progress, done
        var title: String {
            switch self {
            case .todo: return String(localized: "To Do")
            case .progress: return String(localized: "In Progress")
            case .done: return String(localized: "Done")
            }
        }
        var emptyText: String {
            switch self {
            case .todo: return String(localized: "Nothing to do")
            case .progress: return String(localized: "Nothing in progress")
            case .done: return String(localized: "Nothing done this week")
            }
        }
        var types: Set<String> {
            switch self {
            case .todo: return ["unstarted", "backlog", "triage"]
            case .progress: return ["started"]
            case .done: return ["completed"]
            }
        }
        var glyphType: String {
            switch self {
            case .todo: return "unstarted"
            case .progress: return "started"
            case .done: return "completed"
            }
        }
        var defaultColor: String {
            switch self {
            case .todo: return "#bec2c8"
            case .progress: return "#f2c94c"
            case .done: return "#5e6ad2"
            }
        }
    }

    private var selectedTab: Section {
        if let raw = Int(storedTab), let s = Section(rawValue: raw) { return s }
        return sections.first(where: { $0.section == .progress })?.issues.isEmpty == false ? .progress : .todo
    }

    private func selectTab(_ tab: Section) {
        storedTab = String(tab.rawValue)
    }

    /// Issues de-duplicated by id (open + recently done can overlap briefly around a refresh).
    private var uniqueIssues: [LinearIssue] {
        var seen = Set<String>()
        return service.issues.filter { seen.insert($0.id).inserted }
    }

    fileprivate enum DueChoice: Hashable {
        case none, today, tomorrow, nextMonday

        /// "yyyy-MM-dd" for the choice, nil for none.
        var dayString: String? {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let offset: Int
            switch self {
            case .none: return nil
            case .today: offset = 0
            case .tomorrow: offset = 1
            case .nextMonday:
                // First Monday strictly after today (a Monday jumps a full week).
                let weekday = calendar.component(.weekday, from: today)
                let delta = (2 - weekday + 7) % 7
                offset = delta == 0 ? 7 : delta
            }
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return LinearService.dayString(date)
        }
    }

    public init(
        note: Binding<NoteCard>,
        onSpawnWidget: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self._note = note
        self.onSpawnWidget = onSpawnWidget
        self.onDelete = onDelete
    }

    public var body: some View {
        ZStack(alignment: .top) {
            HeaderImageView(imagePath: note.headerImagePath)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            ZStack(alignment: .top) {
                sheetBackgroundColor
                    .background(.cardMaterial)

                VStack(spacing: 0) {
                    switch service.status {
                    case .notConnected:
                        messageState(
                            icon: .link,
                            title: String(localized: "Connect Linear"),
                            text: String(localized: "Connect your Linear account to see the issues assigned to you."),
                            button: String(localized: "Connect Linear")
                        )
                    case .unauthorized:
                        messageState(
                            icon: .lockFill,
                            title: String(localized: "Reconnect Linear"),
                            text: String(localized: "Linear rejected your API key."),
                            button: String(localized: "Reconnect Linear")
                        )
                    case .loading where service.issues.isEmpty:
                        skeleton
                    default:
                        if let banner = banner { bannerView(banner).padding(.bottom, 8) }
                        issueList
                        footer
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 12)
                .padding(.top, 22) // matches the task card's list inset
                .padding(.bottom, 10)

                if let toast = service.toast {
                    Text(toast)
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundStyle(primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(sheetBackgroundColor, in: Capsule())
                        .background(.cardMaterial, in: Capsule())
                        .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                        .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                        .padding(.horizontal, 16)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 44)
                        .motionTransition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: cardWidth, height: sheetHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .offset(y: headerHeight)
            .zIndex(1)

            headerPills
                .frame(width: cardWidth, height: headerHeight)
                .zIndex(10)
        }
        .frame(width: cardWidth, height: cardHeight)
        .motionAnimation(.easeInOut(duration: 0.2), value: service.toast)
        .motionAnimation(.easeInOut(duration: 0.2), value: service.status)
        .onAppear { service.viewDidAppear() }
        .onDisappear { service.viewDidDisappear() }
        .contextMenu { contextMenuItems }
    }

    // MARK: - Header pills

    private var headerPills: some View {
        HStack(spacing: 8) {
            WidgetHeaderCapsule(isDark: isDark, baseOpacity: settings.backgroundOpacity) {
                HStack(spacing: 6) {
                    RemixImage(.listCheck, scaledSize: 16)
                        .foregroundStyle(accent)
                    Text("Linear")
                        .scaledFont(size: 15, weight: .medium)
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Linear")

            if service.hasKey { filterPill }

            if service.hasKey {
                Button {
                    SensoryFeedback.buttonClicked()
                    service.refresh()
                } label: {
                    headerIconPill(hovering: isHoveringRefresh) {
                        if service.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            RemixImage(.refreshLine, scaledSize: 16)
                                .foregroundStyle(primaryText.opacity(0.9))
                        }
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)
                .onHover { isHoveringRefresh = $0 }
                .disabled(service.isRefreshing)
                .accessibilityLabel("Refresh")
                .help("Refresh (⌘R)")

            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var filterPill: some View {
        let counts = Dictionary(uniqueKeysWithValues: sections.map { ($0.section, $0.issues.count) })
        return WidgetHeaderCapsule(isDark: isDark, baseOpacity: settings.backgroundOpacity) {
            HStack(spacing: 2) {
                ForEach(Section.allCases, id: \.rawValue) { tab in
                    filterSegment("\(tab.title) \(counts[tab] ?? 0)", selected: selectedTab == tab) { selectTab(tab) }
                }
            }
            .padding(.horizontal, -8)
        }
        .accessibilityElement(children: .contain)
    }

    private func filterSegment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !selected else { return }
            SensoryFeedback.buttonClicked()
            withMotion(.easeInOut(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .scaledFont(size: 13, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(selected ? primaryText : secondaryText)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(primaryText.opacity(selected ? (isDark ? 0.14 : 0.09) : 0), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func headerIconPill<Content: View>(hovering: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 36, height: 36)
            .background(buttonBackgroundColor(hovering: hovering), in: Circle())
            .background(.cardMaterial, in: Circle())
            .overlay(Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75))
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
            .contentShape(Circle())
    }

    // MARK: - Data shaping

    private var sections: [(section: Section, color: String, issues: [LinearIssue])] {
        let all = uniqueIssues
        let now = Date()
        return Section.allCases.map { section in
            var items = all.filter { section.types.contains($0.state.type) }
            let sorted: [LinearIssue]
            if section == .done {
                let cutoff = now.addingTimeInterval(-7 * 86_400)
                items = items.filter { (Self.parseTimestamp($0.completedAt) ?? .distantPast) >= cutoff }
                sorted = items.sorted { ($0.completedAt ?? "") > ($1.completedAt ?? "") }
            } else {
                sorted = Self.sortIssues(items)
            }
            return (section, sorted.first?.state.color ?? section.defaultColor, sorted)
        }
    }

    private static func parseTimestamp(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private static func rank(_ p: Int) -> Int { p == 0 ? 5 : p }

    /// Priority (urgent first, none last), then overdue/soonest due, then most recently updated.
    private static func sortIssues(_ items: [LinearIssue]) -> [LinearIssue] {
        items.enumerated().sorted { a, b in
            let ra = rank(a.element.priority), rb = rank(b.element.priority)
            if ra != rb { return ra < rb }
            let da = LinearService.parseDate(a.element.dueDate) ?? .distantFuture
            let db = LinearService.parseDate(b.element.dueDate) ?? .distantFuture
            if da != db { return da < db }
            let ua = a.element.updatedAt ?? "", ub = b.element.updatedAt ?? ""
            if ua != ub { return ua > ub }
            return a.offset < b.offset
        }.map(\.element)
    }

    private var defaultTeamId: String? {
        let counts = Dictionary(grouping: uniqueIssues, by: { $0.team.id }).mapValues(\.count)
        if let best = counts.max(by: { $0.value < $1.value })?.key { return best }
        return service.teams.first?.id
    }

    private var availableTeams: [LinearTeam] {
        if !service.teams.isEmpty { return service.teams }
        var seen = Set<String>()
        return uniqueIssues.map(\.team).filter { seen.insert($0.id).inserted }
    }

    /// Fill amount of the in-progress pie: Linear fills it by the state's order among the team's started states.
    private static func progress(of issue: LinearIssue) -> Double {
        let started = issue.teamStates.filter { $0.type == "started" }
        guard let i = started.firstIndex(where: { $0.id == issue.state.id }), started.count > 1 else { return 0.5 }
        return Double(i + 1) / Double(started.count + 1)
    }

    private static func progress(of state: LinearWorkflowState, in states: [LinearWorkflowState]) -> Double {
        let started = states.filter { $0.type == "started" }
        guard let i = started.firstIndex(where: { $0.id == state.id }), started.count > 1 else { return 0.5 }
        return Double(i + 1) / Double(started.count + 1)
    }

    // MARK: - List

    private var visibleIssues: [LinearIssue] {
        sections.first(where: { $0.section == selectedTab })?.issues ?? []
    }

    private var issueList: some View {
        let tab = selectedTab
        let issues = visibleIssues
        let hasData = service.status == .ready || !uniqueIssues.isEmpty
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                if issues.isEmpty {
                    if hasData {
                        Text(tab.emptyText)
                            .scaledFont(size: 13, weight: .regular)
                            .foregroundStyle(tertiaryText)
                            .padding(.leading, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .motionTransition(.opacity)
                    }
                } else {
                    ForEach(issues) { issue in
                        LinearIssueRow(
                            issue: issue,
                            isDark: isDark,
                            progress: Self.progress(of: issue),
                            onOpen: { service.open(issue) },
                            onSetState: { state in changeState(state, for: issue) },
                            onSetPriority: { value in changePriority(value, for: issue) },
                            onSetDue: { choice in changeDue(choice, for: issue) },
                            onCopy: { service.copy($0) }
                        )
                        .motionTransition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))
                    }
                }
            }
            .id(tab.rawValue)
            .transition(.opacity)
            .padding(.top, 0)
            .padding(.bottom, 8)
            .motionAnimation(.spring(response: 0.38, dampingFraction: 0.86), value: issues.map { $0.id + $0.state.id })
        }
        .id(tab.rawValue)
        .transition(.opacity)
        .motionAnimation(.easeInOut(duration: 0.2), value: tab)
        .contentEdgeFade(top: 8, bottom: 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func changeState(_ state: LinearWorkflowState, for issue: LinearIssue) {
        guard state.id != issue.state.id else { return }
        if state.type == "completed" { SensoryFeedback.taskCompleted() }
        else if issue.state.type == "completed" { SensoryFeedback.taskUnchecked() }
        else { SensoryFeedback.buttonClicked() }
        withMotion(.spring(response: 0.38, dampingFraction: 0.86)) {
            service.setState(state, for: issue)
        }
    }

    private func changeDue(_ choice: DueChoice, for issue: LinearIssue) {
        let day = choice.dayString
        guard day != issue.dueDate else { return }
        SensoryFeedback.buttonClicked()
        withMotion(.spring(response: 0.38, dampingFraction: 0.86)) {
            service.setDueDate(day, for: issue)
        }
    }

    private func changePriority(_ value: Int, for issue: LinearIssue) {
        guard value != issue.priority else { return }
        SensoryFeedback.buttonClicked()
        withMotion(.spring(response: 0.38, dampingFraction: 0.86)) {
            service.setPriority(value, for: issue)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 6) {
                if service.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                }
                if let updated = service.lastUpdated {
                    Text(Self.updatedText(updated, now: context.date))
                } else if service.isRefreshing {
                    Text("Updating…")
                }
            }
            .scaledFont(size: 12, weight: .medium)
            .foregroundStyle(tertiaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 16)
        }
        .padding(.top, 2)
    }

    private static func updatedText(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return String(localized: "Updated just now") }
        let minutes = seconds / 60
        if minutes < 60 { return String(localized: "Updated \(minutes)m ago") }
        let hours = minutes / 60
        if hours < 24 { return String(localized: "Updated \(hours)h ago") }
        return String(localized: "Updated \(hours / 24)d ago")
    }

    // MARK: - Banner (offline / rate limited / failed)

    private struct Banner {
        let icon: RemixIcon
        let text: String
    }

    private var banner: Banner? {
        switch service.status {
        case .offline: return Banner(icon: .wifiOffLine, text: String(localized: "Offline. Showing last known issues."))
        case .rateLimited: return Banner(icon: .hourglassLine, text: String(localized: "Rate limited. Retrying soon."))
        case .failed(let m): return Banner(icon: .alertFill, text: m)
        default: return nil
        }
    }

    private func bannerView(_ banner: Banner) -> some View {
        HStack(spacing: 8) {
            RemixImage(banner.icon, scaledSize: 14)
                .foregroundStyle(Color.orange)
            Text(banner.text)
                .scaledFont(size: 13, weight: .medium)
                .foregroundStyle(primaryText.opacity(0.8))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                SensoryFeedback.buttonClicked()
                service.refresh()
            } label: {
                Text("Retry")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(buttonBackgroundColor(hovering: false), in: Capsule())
                    .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(service.isRefreshing)
            .accessibilityLabel("Retry")
        }
        .padding(.leading, 14)
        .padding(.trailing, 5)
        .frame(minHeight: 36)
        .background(primaryText.opacity(isDark ? 0.07 : 0.045), in: Capsule())
        .motionTransition(.opacity)
    }

    // MARK: - Loading skeleton

    private var skeleton: some View {
        LinearSkeleton(fill: primaryText.opacity(isDark ? 0.10 : 0.07), animate: !reduceMotion)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityLabel("Loading issues")
    }

    // MARK: - Message states (not connected / unauthorized)

    private func messageState(icon: RemixIcon, title: String, text: String, button: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            RemixImage(icon, scaledSize: 23)
                .foregroundStyle(accent)
                .frame(width: 56, height: 56)
                .background(buttonBackgroundColor(hovering: false), in: Circle())
                .overlay(Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                .padding(.bottom, 6)
            Text(title)
                .scaledFont(size: 17, weight: .semibold)
                .foregroundStyle(primaryText)
            Text(text)
                .scaledFont(size: 14, weight: .regular)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                SensoryFeedback.buttonClicked()
                SettingsWindowManager.shared.showSettings(item: .linear)
            } label: {
                Text(button)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 18)
                    .frame(height: 36)
                    .background(buttonBackgroundColor(hovering: false), in: Capsule())
                    .background(.cardMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                    .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.035), radius: 5, x: 0, y: 1.5)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .accessibilityLabel(button)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            CardWallpaperActions.chooseCustomImage($note, panelTitle: String(localized: "Select Linear Card Background Image"))
        } label: {
            RemixLabel("Change Header Image...", .imageLine)
        }
        Button {
            CardWallpaperActions.cycle($note)
        } label: {
            RemixLabel("Next Wallpaper in Pack", .refreshLine)
        }
        Button {
            CardActions.togglePinned($note, haptic: false)
        } label: {
            RemixLabel(note.isPinned ? LocalizedStringKey("Unpin (Wallpaper Canvas Mode)") : LocalizedStringKey("Pin on Top (Floating)"), note.isPinned ? .unpinLine : .pushpinLine)
        }
        Divider()
        Button("New Linear Card") { onSpawnWidget() }
        Button(role: .destructive) {
            SensoryFeedback.taskDeleted()
            onDelete()
        } label: {
            RemixLabel("Delete Widget", .deleteBinLine)
        }
    }
}


// MARK: - Issue row

@MainActor
private struct LinearIssueRow: View {
    let issue: LinearIssue
    let isDark: Bool
    let progress: Double
    let onOpen: () -> Void
    let onSetState: (LinearWorkflowState) -> Void
    let onSetPriority: (Int) -> Void
    let onSetDue: (LinearCardView.DueChoice) -> Void
    let onCopy: (String) -> Void

    @State private var isHovering = false

    private var primaryText: Color { isDark ? .white : .black }
    private var secondaryText: Color { isDark ? .white.opacity(0.6) : .black.opacity(0.5) }
    private var isDone: Bool { issue.state.type == "completed" }

    private static let priorityNames: [(value: Int, name: String)] = [
        (0, String(localized: "No priority")),
        (1, String(localized: "Urgent")),
        (2, String(localized: "High")),
        (3, String(localized: "Medium")),
        (4, String(localized: "Low"))
    ]

    private var priorityName: String {
        Self.priorityNames.first(where: { $0.value == issue.priority })?.name ?? String(localized: "No priority")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Menu {
                statusPicker
            } label: {
                Image(nsImage: LinearGlyphImage.status(type: issue.state.type, hex: issue.state.color, progress: progress))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 20, height: 20)
            .help(issue.state.name)
            .accessibilityLabel(String(localized: "Status: \(issue.state.name)"))
            Image(nsImage: LinearGlyphImage.priority(issue.priority, isDark: isDark))
                .frame(width: 20, height: 20)
                .help(priorityName)
                .accessibilityLabel(String(localized: "Priority: \(priorityName)"))
            Text(issue.title)
                .scaledFont(size: 15, weight: isDone ? .regular : .medium)
                .foregroundStyle(isDone ? secondaryText : primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(issue.title)
            if !isDone, let due = LinearDueChip.make(issue.dueDate) {
                dueChip(due)
            }
            openButton
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(primaryText.opacity(isHovering ? (isDark ? 0.08 : 0.055) : 0))
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering in
            withMotion(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
        .onTapGesture {
            SensoryFeedback.buttonClicked()
            onOpen()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Open in Linear")) { onOpen() }
        .accessibilityAction(named: Text("Due today")) { onSetDue(.today) }
        .accessibilityAction(named: Text("Due tomorrow")) { onSetDue(.tomorrow) }
        .accessibilityAction(named: Text("Due next Monday")) { onSetDue(.nextMonday) }
        .accessibilityAction(named: Text("Clear due date")) { onSetDue(.none) }
        .contextMenu {
            Button("Open in Linear") { onOpen() }
            Divider()
            Menu("Status") { statusPicker }
            Menu("Priority") { priorityPicker }
            Menu("Due date") {
                Button("Today") { onSetDue(.today) }
                Button("Tomorrow") { onSetDue(.tomorrow) }
                Button("Next Monday") { onSetDue(.nextMonday) }
                Divider()
                Button("Clear") { onSetDue(.none) }
                    .disabled(issue.dueDate == nil)
            }
            Divider()
            Button("Copy ID") { onCopy(issue.identifier) }
            Button("Copy Link") { onCopy(issue.url) }
        }
    }

    @ViewBuilder
    private var statusPicker: some View {
        let states = issue.teamStates.isEmpty ? [issue.state] : issue.teamStates
        Picker("Status", selection: Binding(
            get: { issue.state.id },
            set: { id in
                if let state = states.first(where: { $0.id == id }) { onSetState(state) }
            }
        )) {
            ForEach(states) { state in
                Label {
                    Text(state.name)
                } icon: {
                    Image(nsImage: LinearGlyphImage.status(
                        type: state.type,
                        hex: state.color,
                        progress: Self.progress(of: state, in: states)
                    ))
                }
                .tag(state.id)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }

    private static func progress(of state: LinearWorkflowState, in states: [LinearWorkflowState]) -> Double {
        let started = states.filter { $0.type == "started" }
        guard let i = started.firstIndex(where: { $0.id == state.id }), started.count > 1 else { return 0.5 }
        return Double(i + 1) / Double(started.count + 1)
    }

    @ViewBuilder
    private var priorityPicker: some View {
        Picker("Priority", selection: Binding(
            get: { issue.priority },
            set: { onSetPriority($0) }
        )) {
            ForEach(Self.priorityNames, id: \.value) { item in
                Label {
                    Text(item.name)
                } icon: {
                    Image(nsImage: LinearGlyphImage.priority(item.value, isDark: isDark))
                }
                .tag(item.value)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }

    private func dueChip(_ due: LinearDueChip) -> some View {
        let tint: Color = {
            switch due.tone {
            case .overdue: return Color.red
            case .soon: return Color.orange
            case .normal: return secondaryText
            }
        }()
        return Text(due.text)
            .scaledFont(size: 12, weight: .semibold)
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(tint.opacity(due.tone == .normal ? 0.12 : 0.14), in: Capsule())
            .help(due.fullDate)
            .accessibilityLabel(String(localized: "Due \(due.fullDate)"))
    }

    // Hover reveals a small "open in Linear" arrow; the slot is always reserved so rows don't shift.
    private var openButton: some View {
        Button {
            SensoryFeedback.buttonClicked()
            onOpen()
        } label: {
            RemixImage(.arrowRightUpLine, scaledSize: 12.5)
                .foregroundStyle(secondaryText)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .help("Open in Linear")
        .accessibilityLabel(String(localized: "Open \(issue.identifier) in Linear"))
    }
}

// MARK: - Due chip

struct LinearDueChip: Equatable {
    enum Tone { case overdue, soon, normal }
    let text: String
    let tone: Tone
    let fullDate: String

    static func make(_ string: String?, now: Date = Date()) -> LinearDueChip? {
        guard let due = LinearService.parseDate(string) else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: due)).day ?? 0
        let full = due.formatted(date: .abbreviated, time: .omitted)
        switch days {
        case ..<0:
            return LinearDueChip(text: String(localized: "Overdue \(-days)d"), tone: .overdue, fullDate: full)
        case 0:
            return LinearDueChip(text: String(localized: "Today"), tone: .soon, fullDate: full)
        case 1:
            return LinearDueChip(text: String(localized: "Tomorrow"), tone: .normal, fullDate: full)
        case 2...6:
            return LinearDueChip(text: due.formatted(.dateTime.weekday(.abbreviated)), tone: .normal, fullDate: full)
        default:
            return LinearDueChip(text: due.formatted(.dateTime.month(.abbreviated).day()), tone: .normal, fullDate: full)
        }
    }
}

// MARK: - Skeleton

private struct LinearSkeleton: View {
    let fill: Color
    let animate: Bool
    @State private var dim = false

    private let widths: [CGFloat] = [0.72, 0.55, 0.83, 0.47, 0.66]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(fill).frame(width: 14, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(fill).frame(width: 70, height: 11)
            }
            .padding(.top, 6)
            ForEach(widths.indices, id: \.self) { i in
                GeometryReader { geo in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(fill).frame(width: 14, height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(fill).frame(width: 52, height: 11)
                        Circle().fill(fill).frame(width: 14, height: 14)
                        RoundedRectangle(cornerRadius: 5).fill(fill)
                            .frame(width: max(40, (geo.size.width - 120) * widths[i]), height: 13)
                    }
                }
                .frame(height: 16)
            }
        }
        .padding(.horizontal, 10)
        .opacity(dim ? 0.45 : 1)
        .onAppear {
            guard animate else { return }
            withMotion(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
        }
    }
}

extension Color {
    /// Parses "#RRGGBB" Linear colors; falls back to gray.
    init(linearHex hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}
