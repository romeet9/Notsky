import Foundation
import SwiftUI
import Observation

public struct WorkspaceData: Codable {
    public var notes: [NoteCard]
    public var folders: [NoteFolder]?
    
    public init(notes: [NoteCard], folders: [NoteFolder]?) {
        self.notes = notes
        self.folders = folders
    }
}

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
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("Notsky", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("workspace_v1.json")
    }
    
    private static var saveWorkItem: DispatchWorkItem?
    
    public func scheduleAutoSave() {
        Self.saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.saveToDisk()
        }
        Self.saveWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35, execute: item)
    }
    
    public func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let workspace = WorkspaceData(notes: notes, folders: folders)
            let data = try encoder.encode(workspace)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to persist Notsky workspace to disk: \(error)")
        }
    }
    
    public static func loadFromDisk() -> (notes: [NoteCard], folders: [NoteFolder])? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            if let workspace = try? decoder.decode(WorkspaceData.self, from: data) {
                return (workspace.notes, workspace.folders ?? [])
            }
            let legacyNotes = try decoder.decode([NoteCard].self, from: data)
            return (legacyNotes, [])
        } catch {
            print("Failed to load Notsky workspace from disk: \(error)")
            return nil
        }
    }

    public static var defaultDemoFolders: [NoteFolder] {
        return [
            NoteFolder(name: "Projects", icon: "folder.fill"),
            NoteFolder(name: "Personal", icon: "person.crop.circle.fill"),
            NoteFolder(name: "Ideas", icon: "lightbulb.fill")
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
        if let persisted = Self.loadFromDisk() {
            var loadedNotes = persisted.notes
            for i in loadedNotes.indices {
                switch loadedNotes[i].cardType {
                case .tasks:
                    loadedNotes[i].width = 281
                    loadedNotes[i].height = 364
                case .notes:
                    loadedNotes[i].width = 586
                    loadedNotes[i].height = 364
                case .finder, .folders:
                    loadedNotes[i].width = 360
                    loadedNotes[i].height = 364
                }
            }
            self.notes = loadedNotes
            self.folders = persisted.folders.isEmpty ? Self.defaultDemoFolders : persisted.folders
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
            title: "Tasks",
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
            title: "Tasks",
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
            pages: [NotePage(title: "Untitled", content: "")],
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
            title: "notskyai",
            noteContent: "",
            headerImagePath: w3,
            items: [],
            chatMessages: [],
            gridCol: 2,
            gridRow: 0,
            width: 360,
            height: 364
        )
        
        self.notes = [card1, card2, card3, card4]
        saveToDisk()
    }
    
    // MARK: - Folder Management
    @discardableResult
    public func createFolder(name: String, icon: String = "folder.fill", colorHex: String? = nil) -> NoteFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderName = trimmed.isEmpty ? "New Folder" : trimmed
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
        return notes.filter { $0.folderId == folderId && $0.cardType != .finder && $0.cardType != .folders }
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
    
    public func addFreeformNote(title: String = "Quick Note", content: String = "") {
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
            width: 360,
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
            title: "Finder AI",
            noteContent: "",
            headerImagePath: nextWallpaper,
            items: [],
            chatMessages: [],
            positionX: 120 + offset,
            positionY: 120 + offset,
            width: 360,
            height: 364
        )
        notes.append(newCard)
    }
    
    public func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }
}

