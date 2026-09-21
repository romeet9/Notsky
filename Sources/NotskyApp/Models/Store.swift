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
            let data = try encoder.encode(notes)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to persist Notsky workspace to disk: \(error)")
        }
    }
    
    public static func loadFromDisk() -> [NoteCard]? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode([NoteCard].self, from: data)
            return loaded.isEmpty ? nil : loaded
        } catch {
            print("Failed to load Notsky workspace from disk: \(error)")
            return nil
        }
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
            self.notes = persisted
            return
        }
        
        let packs = WallpaperPackManager.builtInPacks()
        let items = packs.first?.items ?? []
        
        let w0 = items.indices.contains(0) ? items[0].path : WallpaperPackManager.shared.nextWallpaperPath()
        let w1 = items.indices.contains(4) ? items[4].path : (items.indices.contains(1) ? items[1].path : WallpaperPackManager.shared.nextWallpaperPath())
        let w2 = items.indices.contains(2) ? items[2].path : WallpaperPackManager.shared.nextWallpaperPath()
        let w3 = items.indices.contains(1) ? items[1].path : (items.indices.contains(3) ? items[3].path : WallpaperPackManager.shared.nextWallpaperPath())
        
        let card1 = NoteCard(
            cardType: .tasks,
            title: "Design Iterations",
            headerImagePath: w0,
            items: [
                NoteItem(text: "Explore liquid-glass refraction shaders", isCompleted: true),
                NoteItem(text: "Refine superellipse continuous corners (40pt)", isCompleted: true),
                NoteItem(text: "Tune dynamic wallpaper luminance tinting", isCompleted: true),
                NoteItem(text: "Test multi-monitor cursor magnetic snapping", isCompleted: false),
                NoteItem(text: "Polish over-dock slide shelf animations", isCompleted: false)
            ],
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
            title: "Launch Checklist",
            headerImagePath: w1,
            items: [
                NoteItem(text: "Finalize macOS AppIcon & Dock integration", isCompleted: true),
                NoteItem(text: "Verify template menu bar icon optical height", isCompleted: true),
                NoteItem(text: "Test slide-up drawer over sticky dock", isCompleted: true),
                NoteItem(text: "Render 4K UI widget showcase mockups", isCompleted: true),
                NoteItem(text: "Ship v1.0.0 release build to GitHub", isCompleted: false)
            ],
            gridCol: 1,
            gridRow: 0,
            width: 281,
            height: 364,
            timerDuration: 25 * 60,
            timeRemaining: 18 * 60 + 42,
            isTimerRunning: true
        )
        
        let card3 = NoteCard(
            cardType: .notes,
            title: "Strategy & Notes",
            noteContent: Self.defaultDemoNoteContent,
            pages: Self.defaultDemoPages,
            activePageIndex: 0,
            headerImagePath: w2,
            items: [],
            gridCol: 0,
            gridRow: 1,
            width: 586,
            height: 364
        )
        
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let sampleFiles = [
            FinderFileItem(name: "Q3_Product_Roadmap.pdf", path: "\(home)/Documents/Q3_Product_Roadmap.pdf", fileSize: "2.4 MB", fileType: "PDF Document", summary: "Contains spatial physics engine deliverables & Q3 milestones", formattedDate: "Today, 2:15 PM"),
            FinderFileItem(name: "Design_System_Tokens.pdf", path: "\(home)/Documents/Design_System_Tokens.pdf", fileSize: "5.1 MB", fileType: "PDF Document", summary: "Mac OS optical depth, continuous corner radius & materials spec", formattedDate: "Yesterday"),
            FinderFileItem(name: "Notsky_Release_Notes.md", path: "\(home)/Documents/Notsky_Release_Notes.md", fileSize: "14 KB", fileType: "Markdown", summary: "v1.0.0 production release changelog and installer build steps", formattedDate: "Sep 20, 2026")
        ]
        
        let card4 = NoteCard(
            cardType: .finder,
            title: "notskyai",
            noteContent: "",
            headerImagePath: w3,
            items: [],
            chatMessages: [
                ChatMessage(role: "user", content: "Find recent architectural specs and roadmap PDFs"),
                ChatMessage(role: "assistant", content: "I indexed your local documents and located 3 relevant design and engineering files:", attachedFiles: sampleFiles)
            ],
            gridCol: 2,
            gridRow: 0,
            width: 586,
            height: 752
        )
        
        self.notes = [card1, card2, card3, card4]
        saveToDisk()
    }
    
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
        // Width is sum of two cards (281 * 2) + space between them (24) = 586 pt
        let doubleCardWidth: Double = 281.0 * 2.0 + 24.0
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
            width: doubleCardWidth,
            height: 364
        )
        notes.append(newCard)
    }
    
    public func addFinderNote() {
        let count = notes.count
        let offset = Double(count * 40)
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        // Width: 281 * 2 + 24 = 586 pt, Height: 364 * 2 + 24 = 752 pt
        let doubleCardWidth: Double = 281.0 * 2.0 + 24.0
        let doubleCardHeight: Double = 364.0 * 2.0 + 24.0
        let newCard = NoteCard(
            cardType: .finder,
            title: "Finder AI",
            noteContent: "",
            headerImagePath: nextWallpaper,
            items: [],
            chatMessages: [],
            positionX: 120 + offset,
            positionY: 120 + offset,
            width: doubleCardWidth,
            height: doubleCardHeight
        )
        notes.append(newCard)
    }
    
    public func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }
}

