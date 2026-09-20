import Foundation
import SwiftUI
import Observation

@Observable
public final class NoteStore {
    public var notes: [NoteCard] = []
    
    public static let defaultDemoNoteContent: String = """
**Design & Strategy Notes**

• **Visual Hierarchy**: Frosted glass depth with 3D specular light borders.
• *Typography & Clarity*: Native bold, italic, and bullet lists.
• *Focus Flow*: Minimal friction note-taking directly from your desktop.

*“Simplicity is about subtracting the obvious and adding the meaningful.”*
"""

    public static let defaultDemoPages: [NotePage] = [
        NotePage(
            title: "Strategy",
            content: """
**Design & Strategy Notes**

• **Visual Hierarchy**: Frosted glass depth with 3D specular light borders.
• *Typography & Clarity*: Native bold, italic, and bullet lists.
• *Focus Flow*: Minimal friction note-taking directly from your desktop.

*“Simplicity is about subtracting the obvious and adding the meaningful.”*
"""
        ),
        NotePage(
            title: "Ideas",
            content: """
**Product Ideas & Brainstorming**

• **Multi-Tab Cards**: Keep workspace tidy with tabbed desktop cards.
• *Trackpad Gestures*: Swipe smoothly between note tabs.
• *Rich 4K Cards*: Instant wallpaper exports for sharing on social platforms.

*“Creativity is thinking up new things. Innovation is doing new things.”*
"""
        ),
        NotePage(
            title: "Snippets",
            content: """
**Developer & Design Snippets**

• `git commit -m "feat: multi-tab quick notes"`
• `swift build -c release`
• *Material Formula*: `.ultraThinMaterial` + `specularBorderGradient`

*“Make it work, make it right, make it fast.”*
"""
        )
    ]

    public init() {
        let pack = WallpaperPackManager.shared.activePack
        let items = pack.items
        let path0 = items.indices.contains(0) ? items[0].path : "/Users/romeet/Downloads/red_distortion_2.heic"
        let path1 = items.indices.contains(1) ? items[1].path : "preset://aurora_violet"
        let path2 = items.indices.contains(2) ? items[2].path : "preset://aurora_sunset"
        let path3 = items.indices.contains(3) ? items[3].path : "preset://aurora_emerald"
        
        // Initial notes layout:
        // Top Row: 2 Task Cards
        // Bottom Row: AI Notes (586x364)
        // Right Side: notskyai Finder (586x752)
        self.notes = [
            NoteCard(
                title: "Design Iterations",
                headerImagePath: path0,
                items: [
                    NoteItem(text: "Refine widget glassmorphism & specular borders", isCompleted: true),
                    NoteItem(text: "Implement 2-column grid layout with 24pt gutter", isCompleted: true),
                    NoteItem(text: "Tune dark mode ambient drop shadows & diffusion", isCompleted: false),
                    NoteItem(text: "Design responsive card resize handles", isCompleted: false),
                    NoteItem(text: "Audit SF Pro typography and tracking", isCompleted: false)
                ],
                gridCol: 0,
                gridRow: 0,
                width: 281,
                height: 364
            ),
            NoteCard(
                title: "Launch Checklist",
                headerImagePath: path1,
                items: [
                    NoteItem(text: "Finalize macOS native AppKit desktop integration", isCompleted: true),
                    NoteItem(text: "Configure auto-launch on system startup", isCompleted: false),
                    NoteItem(text: "Test multi-display grid snapping behavior", isCompleted: false),
                    NoteItem(text: "Prepare Product Hunt release assets", isCompleted: false),
                    NoteItem(text: "Record 60fps quick demo walkthrough video", isCompleted: false)
                ],
                gridCol: 1,
                gridRow: 0,
                width: 281,
                height: 364
            ),
            NoteCard(
                cardType: .notes,
                title: "Strategy",
                noteContent: NoteStore.defaultDemoNoteContent,
                pages: NoteStore.defaultDemoPages,
                activePageIndex: 0,
                headerImagePath: path2,
                items: [],
                gridCol: 0,
                gridRow: 1,
                width: 586,
                height: 364
            ),
            NoteCard(
                cardType: .finder,
                title: "notskyai",
                noteContent: "",
                headerImagePath: path3,
                items: [],
                chatMessages: [],
                gridCol: 2,
                gridRow: 0,
                width: 586,
                height: 752
            )
        ]
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
    
    public func addFreeformNote(title: String = "Quick Note", content: String = NoteStore.defaultDemoNoteContent) {
        let count = notes.count
        let offset = Double(count * 40)
        let nextWallpaper = WallpaperPackManager.shared.nextWallpaperPath()
        // Width is sum of two cards (281 * 2) + space between them (24) = 586 pt
        let doubleCardWidth: Double = 281.0 * 2.0 + 24.0
        let newCard = NoteCard(
            cardType: .notes,
            title: title,
            noteContent: content,
            pages: NoteStore.defaultDemoPages,
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

