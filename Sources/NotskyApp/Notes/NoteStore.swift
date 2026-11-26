import Foundation
import SwiftUI
import Observation

@Observable
public final class NoteStore {
    public var notes: [NoteCard] = [] {
        didSet {
            scheduleAutoSave()
        }
    }
    
    public var folders: [NoteFolder] = [] {
        didSet {
            scheduleAutoSave()
        }
    }
    
    private static var storageURL: URL {
        AppPaths.workspaceFile
    }
    
    private static var saveWorkItem: DispatchWorkItem?
    private static let ioQueue = DispatchQueue(label: "notsky.store.io", qos: .utility)
    
    /// Debounced autosave. The snapshot of notes/folders is taken on the main thread;
    /// encoding and the atomic write happen off-main on a serial queue.
    public func scheduleAutoSave() {
        guard Thread.isMainThread else {
            Task { @MainActor [weak self] in self?.scheduleAutoSave() }
            return
        }
        Self.saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let snapshot = WorkspaceData(notes: self.notes, folders: self.folders)
            Self.ioQueue.async { Self.write(snapshot) }
        }
        Self.saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
    
    /// Immediate save (snapshot on the calling thread, which must be main; write serialized with autosaves).
    public func saveToDisk() {
        let snapshot = WorkspaceData(notes: notes, folders: folders)
        Self.ioQueue.sync { Self.write(snapshot) }
    }
    
    private static func write(_ workspace: WorkspaceData) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(workspace)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            Log.store.error("Failed to persist workspace to disk: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Copies the current store file to `<name>.bak-<timestamp>` next to it. Returns the backup URL, or nil on failure
    /// (or nil if there is no file to back up).
    @discardableResult
    public static func backupStoreFile(reason: String) -> URL? {
        let fm = FileManager.default
        let source = storageURL
        guard fm.fileExists(atPath: source.path) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backup = source.deletingLastPathComponent()
            .appendingPathComponent("\(source.lastPathComponent).bak-\(formatter.string(from: Date.now))")
        do {
            if fm.fileExists(atPath: backup.path) { try fm.removeItem(at: backup) }
            try fm.copyItem(at: source, to: backup)
            Log.store.info("Workspace backup (\(reason, privacy: .public)) written to \(backup.path, privacy: .public)")
            return backup
        } catch {
            Log.store.error("Failed to back up workspace (\(reason, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    public enum LoadResult {
        case none
        case loaded(notes: [NoteCard], folders: [NoteFolder])
        case failed
    }
    
    public static func loadFromDisk() -> LoadResult {
        AppPaths.migrateWorkspaceFromNotskyIfNeeded()
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return .none }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            if let workspace = try? decoder.decode(WorkspaceData.self, from: data) {
                return .loaded(notes: workspace.notes, folders: workspace.folders ?? [])
            }
            let legacyNotes = try decoder.decode([NoteCard].self, from: data)
            return .loaded(notes: legacyNotes, folders: [])
        } catch {
            Log.store.error("Failed to load workspace from disk: \(error.localizedDescription, privacy: .public)")
            // The file exists but is unreadable: keep a copy before anything can overwrite it.
            backupStoreFile(reason: "decode-failure")
            return .failed
        }
    }

    public static var defaultDemoFolders: [NoteFolder] {
        return [
            NoteFolder(name: String(localized: "Projects"), icon: "folder.fill"),
            NoteFolder(name: String(localized: "Personal"), icon: "person.crop.circle.fill"),
            NoteFolder(name: String(localized: "Ideas"), icon: "lightbulb.fill")
        ]
    }

    public static var defaultDemoNoteContent: String {
        """
**Core Architecture Principles**

• **Zero-Latency Spatial Physics**: Native AppKit NSPanel windows with hardware acceleration.

• **Dynamic Visual Cohesion**: Background-aware chromatic adaptation.

• **Spatial Canvas Freedom**: Independent movable widgets with magnetic snapping.
"""
    }

    public static var defaultDemoPages: [NotePage] {
        let strategyContent = defaultDemoNoteContent
        let ideasContent = """
**Product Ideas & Brainstorming**

• **Multi-Tab Cards**: Keep workspace tidy with tabbed desktop cards.
• **Trackpad Gestures**: Swipe smoothly between note tabs.
• **Rich 4K Cards**: Instant wallpaper exports for sharing on social platforms.
"""
        let snippetsContent = """
**Developer & Design Snippets**

• `git commit -m "feat: multi-tab quick notes"`
• `swift build -c release`
• **Material Formula**: `.ultraThinMaterial` + `specularBorderGradient`
"""
        return [
            NotePage(title: "Strategy", content: strategyContent),
            NotePage(title: "Ideas", content: ideasContent),
            NotePage(title: "Snippets", content: snippetsContent)
        ]
    }
    
    public init() {
        if case .loaded(let persistedNotes, let persistedFolders) = Self.loadFromDisk() {
            // Pixel sizes are derived from grid spans at layout time (WidgetWindowManager).
            var loadedNotes = persistedNotes
            // Chats start fresh on every launch.
            for i in loadedNotes.indices { loadedNotes[i].chatMessages = [] }
            self.notes = loadedNotes
            self.folders = persistedFolders.isEmpty ? Self.defaultDemoFolders : persistedFolders
            saveToDisk()
            return
        }
        
        let demoFolders = Self.defaultDemoFolders
        self.folders = demoFolders
        
        let packs = WallpaperPackManager.builtInPacks()
        let items = packs.first?.items ?? []
        
        let w0 = items.indices.contains(0) ? items[0].path : WallpaperPackManager.shared.nextWallpaperPath()
        let w1 = items.indices.contains(4) ? items[4].path : (items.indices.contains(1) ? items[1].path : WallpaperPackManager.shared.nextWallpaperPath())
        let w2 = items.indices.contains(2) ? items[2].path : WallpaperPackManager.shared.nextWallpaperPath()
        let w3 = items.indices.contains(1) ? items[1].path : (items.indices.contains(3) ? items[3].path : WallpaperPackManager.shared.nextWallpaperPath())
        
        let card1 = NoteCard(
            cardType: .tasks,
            title: String(localized: "Tasks"),
            headerImagePath: w0,
            items: [],
            folderId: demoFolders.first?.id,
            gridCol: 0,
            gridRow: 0,
            width: 281,
            height: 364,
            timerDuration: 25 * 60,
            timeRemaining: 25 * 60,
            isTimerRunning: false
        )
        
        let card2 = NoteCard(
            cardType: .tasks,
            title: String(localized: "Tasks"),
            headerImagePath: w1,
            items: [],
            folderId: demoFolders.indices.contains(1) ? demoFolders[1].id : nil,
            gridCol: 1,
            gridRow: 0,
            width: 281,
            height: 364,
            timerDuration: 25 * 60,
            timeRemaining: 25 * 60,
            isTimerRunning: false
        )
        
        let card3 = NoteCard(
            cardType: .notes,
            title: "Notes",
            noteContent: "",
            pages: [NotePage(title: String(localized: "Untitled"), content: "")],
            activePageIndex: 0,
            headerImagePath: w2,
            items: [],
            folderId: demoFolders.first?.id,
            gridCol: 0,
            gridRow: 1,
            width: 586,
            height: 364
        )
        
        let card4 = NoteCard(
            cardType: .finder,
            title: "Notsky AI",
            noteContent: "",
            headerImagePath: w3,
            items: [],
            chatMessages: [],
            gridCol: 2,
            gridRow: 0,
            width: 586,
            height: 364
        )
        
        self.notes = [card1, card2, card3, card4]
        saveToDisk()
    }
    
    // MARK: - Folder Management
    @discardableResult
    public func createFolder(name: String, icon: String = "folder.fill", colorHex: String? = nil) -> NoteFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderName = trimmed.isEmpty ? String(localized: "New Folder") : trimmed
        let newFolder = NoteFolder(name: folderName, icon: icon, colorHex: colorHex)
        folders.append(newFolder)
        return newFolder
    }
    
    public func renameFolder(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = folders.firstIndex(where: { $0.id == id }) {
            folders[idx].name = trimmed
        }
    }
    
    public func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        // Remove folder association from any notes
        for i in notes.indices {
            if notes[i].folderId == id {
                notes[i].folderId = nil
            }
        }
    }
    
    public func folder(for id: UUID?) -> NoteFolder? {
        guard let id = id else { return nil }
        return folders.first { $0.id == id }
    }
    
    public func notes(in folderId: UUID?) -> [NoteCard] {
        return notes.filter { $0.folderId == folderId && $0.cardType != .finder && $0.cardType != .folders && $0.cardType != .nowPlaying && $0.cardType != .linear && $0.cardType != .voiceOpen }
    }
    
    // MARK: - Card Actions
    public func addNote() {
        let count = notes.count
        let offset = Double(count * 40)
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newCard = NoteCard(
            cardType: .tasks,
            title: "New Group",
            headerImagePath: nextWallpaper,
            items: [
                NoteItem(text: "Write your first task here...", isCompleted: false)
            ],
            positionX: 120 + offset,
            positionY: 120 + offset,
            width: 281,
            height: 364
        )
        notes.append(newCard)
    }
    
    public func addFreeformNote(title: String = String(localized: "Quick Note"), content: String = "") {
        let count = notes.count
        let offset = Double(count * 40)
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newCard = NoteCard(
            cardType: .notes,
            title: title,
            noteContent: content,
            pages: [NotePage(title: "Note 1", content: content)],
            activePageIndex: 0,
            headerImagePath: nextWallpaper,
            items: [],
            positionX: 120 + offset,
            positionY: 120 + offset,
            width: 586,
            height: 364
        )
        notes.append(newCard)
    }
    
    public func addFoldersNote() {
        let count = notes.count
        let offset = Double(count * 40)
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newCard = NoteCard(
            cardType: .folders,
            title: "Folders",
            noteContent: "",
            headerImagePath: nextWallpaper,
            items: [],
            chatMessages: [],
            positionX: 120 + offset,
            positionY: 120 + offset,
            width: 281,
            height: 364
        )
        notes.append(newCard)
    }
    
    public func addFinderNote() {
        let count = notes.count
        let offset = Double(count * 40)
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        let newCard = NoteCard(
            cardType: .finder,
            title: "Notsky AI",
            noteContent: "",
            headerImagePath: nextWallpaper,
            items: [],
            chatMessages: [],
            positionX: 120 + offset,
            positionY: 120 + offset,
            width: 586,
            height: 364
        )
        notes.append(newCard)
    }
    
    public func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }
}
