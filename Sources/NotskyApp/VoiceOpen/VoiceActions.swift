import AppKit

/// Runs a parsed VoiceCommand against Notsky's own managers. Nothing here touches files, apps or the network.
@MainActor
enum VoiceActions {
    struct Done {
        let message: String
        /// Reverses the change (task, note and new-widget commands only).
        let undo: (@MainActor () -> Void)?
    }

    struct Failure: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }

    /// When each card last received something by voice; breaks ties for "the most recent" card.
    private static var lastUsed: [UUID: Date] = [:]

    private static var manager: WidgetWindowManager { WidgetWindowManager.shared }
    private static var cards: [NoteCard] { manager.store.notes }

    static func run(_ command: VoiceCommand) async throws -> Done {
        switch command {
        case .unknown:
            throw Failure(VoiceCommand.hint)
        case .add(let kind, let rest):
            let target = try resolve(kind: kind, rest: rest)
            return target.kind == .task
                ? addTask(target.text, cardId: target.cardId)
                : addNote(target.text, cardId: target.cardId)
        case .newTaskGroup(let name, let items):
            return newTaskGroup(name: name, items: items)
        case .newNote(let name):
            return newNote(name: name)
        case .music(let music):
            return try await runMusic(music)
        }
    }

    // MARK: - Target resolution

    private struct Target {
        var kind: VoiceCommand.Kind   // .task or .note
        var text: String
        var cardId: UUID?
    }

    private static let notesWords: Set<String> = ["notes", "note", "notebook", "note card", "notes card"]
    private static let tasksWords: Set<String> = ["tasks", "task", "task list", "tasks list", "to do", "todo", "to do list", "todo list", "to dos", "list", "reminders"]

    /// Splits "<text> to <card name>" at the last " to/in/on " whose tail names a real card (or "notes"/"tasks").
    private static func resolve(kind: VoiceCommand.Kind, rest: String) throws -> Target {
        let fallbackKind: VoiceCommand.Kind = kind == .note ? .note : .task
        let ns = rest as NSString
        let separators = (try? NSRegularExpression(pattern: #"\s+(?:to|in|into|on|onto)\s+"#, options: .caseInsensitive))?
            .matches(in: rest, range: NSRange(location: 0, length: ns.length)) ?? []

        var lastName = ""
        for sep in separators.reversed() {
            let text = ns.substring(to: sep.range.location)
            let name = ns.substring(from: sep.range.location + sep.range.length)
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            if lastName.isEmpty { lastName = VoiceCommand.tidyText(name) }
            if let hit = target(named: name, kind: kind) {
                return Target(kind: hit.kind, text: cleanText(text, kind: hit.kind), cardId: hit.id)
            }
        }
        if kind == .any {
            if lastName.isEmpty { throw Failure(VoiceCommand.hint) }
            throw Failure(String(localized: "No card called “\(lastName)”"))
        }
        return Target(kind: fallbackKind, text: cleanText(rest, kind: fallbackKind), cardId: nil)
    }

    private static func cleanText(_ s: String, kind: VoiceCommand.Kind) -> String {
        kind == .note
            ? VoiceCommand.capitalized(s.trimmingCharacters(in: .whitespacesAndNewlines))
            : VoiceCommand.capitalized(VoiceCommand.tidyText(s))
    }

    private static func target(named raw: String, kind: VoiceCommand.Kind) -> (kind: VoiceCommand.Kind, id: UUID?)? {
        var name = VoiceCommand.tidyText(raw)
        if let r = name.range(of: #"^(?:my|the|this|that|a)\s+"#, options: [.regularExpression, .caseInsensitive]) { name.removeSubrange(r) }
        guard !name.isEmpty else { return nil }
        var stripped = name
        if let r = stripped.range(of: #"\s+(?:list|card|widget|group)$"#, options: [.regularExpression, .caseInsensitive]) { stripped.removeSubrange(r) }

        var best: (card: NoteCard, score: Int)?
        for card in cards where (card.cardType == .tasks && kind != .note) || (card.cardType == .notes && kind != .task) {
            let score = max(VoiceCommand.nameScore(spoken: name, title: card.title), VoiceCommand.nameScore(spoken: stripped, title: card.title))
            guard score >= 2 else { continue }
            if best == nil || score > best!.score || (score == best!.score && isMoreRecent(card.id, than: best!.card.id)) {
                best = (card, score)
            }
        }
        if let best { return (best.card.cardType == .notes ? .note : .task, best.card.id) }

        let norm = VoiceCommand.normalizeName(name)
        if kind != .task, notesWords.contains(norm) { return (.note, nil) }
        if kind != .note, tasksWords.contains(norm) { return (.task, nil) }
        return nil
    }

    private static func isMoreRecent(_ a: UUID, than b: UUID) -> Bool {
        (lastUsed[a] ?? .distantPast) > (lastUsed[b] ?? .distantPast)
    }

    /// The card in focus if it matches, else the one last used by voice, else the newest.
    private static func defaultCard(_ type: CardType) -> UUID? {
        let candidates = cards.filter { $0.cardType == type }
        guard !candidates.isEmpty else { return nil }
        if let id = (NSApp.keyWindow as? WidgetPanel)?.noteId, candidates.contains(where: { $0.id == id }) { return id }
        if let recent = candidates.filter({ lastUsed[$0.id] != nil }).max(by: { lastUsed[$0.id]! < lastUsed[$1.id]! }) { return recent.id }
        return candidates.last?.id
    }

    private static func index(of id: UUID) -> Int? { manager.store.notes.firstIndex { $0.id == id } }

    private static func touch(_ id: UUID) { lastUsed[id] = Date() }

    // MARK: - Tasks

    private static func addTask(_ text: String, cardId: UUID?) -> Done {
        guard !text.isEmpty else { return Done(message: VoiceCommand.hint, undo: nil) }
        var id = cardId ?? defaultCard(.tasks)
        var created = false
        if id == nil {
            id = manager.spawnNewWidget(title: String(localized: "Tasks"))
            if id == nil { return Done(message: WidgetWindowManager.noRoomMessage, undo: nil) }
            created = true
        }
        guard let id, let idx = index(of: id) else { return Done(message: VoiceCommand.hint, undo: nil) }

        let item = NoteItem(text: text)
        manager.store.notes[idx].items.insert(item, at: 0)
        SensoryFeedback.taskAdded()
        touch(id)
        if !created { manager.focusWidget(for: id) }
        let title = manager.store.notes[idx].title
        return Done(message: String(localized: "Added “\(text)” to \(title)")) {
            if created {
                manager.closeWidget(noteId: id)
            } else if let i = index(of: id) {
                manager.store.notes[i].items.removeAll { $0.id == item.id }
            }
        }
    }

    private static func newTaskGroup(name: String?, items: [String]) -> Done {
        let title = name ?? String(localized: "Tasks")
        guard let id = manager.spawnNewWidget(title: title, items: items.map { NoteItem(text: $0) }) else { return Done(message: WidgetWindowManager.noRoomMessage, undo: nil) }
        touch(id)
        SensoryFeedback.taskAdded()
        return Done(message: String(localized: "Created task group “\(title)”")) {
            manager.closeWidget(noteId: id)
        }
    }

    // MARK: - Notes

    private static func addNote(_ text: String, cardId: UUID?) -> Done {
        guard !text.isEmpty else { return Done(message: VoiceCommand.hint, undo: nil) }
        guard let id = cardId ?? defaultCard(.notes) else {
            let title = String(localized: "Notes")
            guard let id = manager.spawnNewFreeformNoteWidget(title: title, pages: [NotePage(title: String(localized: "Untitled"), content: text)]) else { return Done(message: WidgetWindowManager.noRoomMessage, undo: nil) }
            touch(id)
            return Done(message: String(localized: "Added to \(title)")) { manager.closeWidget(noteId: id) }
        }
        guard let idx = index(of: id) else { return Done(message: VoiceCommand.hint, undo: nil) }

        if manager.store.notes[idx].pages.isEmpty {
            manager.store.notes[idx].pages = [NotePage(title: "Note 1", content: manager.store.notes[idx].noteContent)]
            manager.store.notes[idx].activePageIndex = 0
        }
        let page = min(max(0, manager.store.notes[idx].activePageIndex), manager.store.notes[idx].pages.count - 1)
        manager.store.notes[idx].activePageIndex = page
        let pageId = manager.store.notes[idx].pages[page].id
        let old = manager.store.notes[idx].pages[page].content
        let joiner = old.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : (old.hasSuffix("\n\n") ? "" : old.hasSuffix("\n") ? "\n" : "\n\n")
        let new = (old.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : old) + joiner + text
        manager.store.notes[idx].pages[page].content = new
        manager.store.notes[idx].noteContent = new
        SensoryFeedback.taskAdded()
        touch(id)
        manager.focusWidget(for: id)
        let title = manager.store.notes[idx].title
        return Done(message: String(localized: "Added to \(title)")) {
            guard let i = index(of: id), let p = manager.store.notes[i].pages.firstIndex(where: { $0.id == pageId }),
                  manager.store.notes[i].pages[p].content == new else { return }
            manager.store.notes[i].pages[p].content = old
            if manager.store.notes[i].activePageIndex == p { manager.store.notes[i].noteContent = old }
        }
    }

    private static func newNote(name: String?) -> Done {
        let title = name ?? String(localized: "Notes")
        guard let id = manager.spawnNewFreeformNoteWidget(title: title, pages: [NotePage(title: name ?? String(localized: "Untitled"), content: "")]) else { return Done(message: WidgetWindowManager.noRoomMessage, undo: nil) }
        touch(id)
        return Done(message: String(localized: "Created note “\(title)”")) { manager.closeWidget(noteId: id) }
    }

    // MARK: - Music

    private static func runMusic(_ command: VoiceCommand.Music) async throws -> Done {
        let player = NowPlayingService.shared
        VoiceOpenService.shared.keepMusicRunning()
        if !player.hasTrack {
            for _ in 0..<10 where !player.hasTrack { try? await Task.sleep(nanoseconds: 150_000_000) }
        }
        guard player.hasTrack else { throw Failure(String(localized: "No music is playing. Open Music or Spotify first.")) }

        switch command {
        case .play:
            if !player.isPlaying { player.togglePlayPause() }
            return Done(message: String(localized: "Playing"), undo: nil)
        case .pause:
            if player.isPlaying { player.togglePlayPause() }
            return Done(message: String(localized: "Paused"), undo: nil)
        case .next:
            player.nextTrack()
            return Done(message: String(localized: "Skipped to next song"), undo: nil)
        case .previous:
            player.previousTrack()
            return Done(message: String(localized: "Back to previous song"), undo: nil)
        case .nowPlaying:
            let line = player.artist.isEmpty ? player.title : "\(player.title) – \(player.artist)"
            return Done(message: line, undo: nil)
        }
    }
}
