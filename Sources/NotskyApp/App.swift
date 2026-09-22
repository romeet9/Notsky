import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("Notsky runs persistent desktop widgets and menu bar")

        let bundlePath = Bundle.main.bundlePath
        if bundlePath.hasPrefix("/Volumes/") {
            // User launched directly from DMG volume.
            // Copy to /Applications, clear quarantine, launch installed app, and exit volume process.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", """
            cp -R "\(bundlePath)" "/Applications/Notsky.app" 2>/dev/null || true
            xattr -cr "/Applications/Notsky.app" 2>/dev/null || true
            open "/Applications/Notsky.app"
            """]
            try? process.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.terminate(nil)
            }
            return
        }

        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.romeet.notsky")
        for app in runningApps where app != NSRunningApplication.current {
            app.terminate()
        }
        
        WallpaperPackManager.ensureWallpapersSeeded()
        
        if CommandLine.arguments.contains("--generate-screenshots") {
            generateShowcaseScreenshots()
            NSApp.terminate(nil)
            return
        }
        
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconImg = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImg
        } else if let iconImg = NSImage(contentsOfFile: "/Applications/Notsky.app/Contents/Resources/AppIcon.icns") {
            NSApp.applicationIconImage = iconImg
        }
        AppSettings.shared.applyDockPolicy()
        
        if CommandLine.arguments.contains("--fill-demo-data") {
            WidgetWindowManager.shared.fillDemoData()
        } else {
            WidgetWindowManager.shared.start()
        }
        GlobalHotKeyManager.shared.setup()
    }
    
    @MainActor
    private func generateShowcaseScreenshots() {
        let docsDir = URL(fileURLWithPath: "/Users/romeet/.gemini/antigravity/scratch/NotskyApp/docs/screenshots")
        try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        
        let packs = WallpaperPackManager.builtInPacks()
        let items = packs.first?.items ?? []
        
        let w1 = items.indices.contains(0) ? items[0].path : "/Users/romeet/Downloads/red_distortion_2.heic"
        let w2 = items.indices.contains(4) ? items[4].path : "/Users/romeet/Downloads/blue_distortion_1.heic"
        let w3 = items.indices.contains(2) ? items[2].path : "/Users/romeet/Downloads/red_distortion_3.heic"
        let w4 = items.indices.contains(1) ? items[1].path : "/Users/romeet/Downloads/red_distortion_1.heic"
        
        let card1 = NoteCard(
            cardType: .tasks,
            title: "Design Iterations",
            headerImagePath: w1,
            items: [
                NoteItem(text: "Explore liquid-glass refraction shaders", isCompleted: true),
                NoteItem(text: "Refine superellipse continuous corners (40pt)", isCompleted: true),
                NoteItem(text: "Tune dynamic wallpaper luminance tinting", isCompleted: true),
                NoteItem(text: "Test multi-monitor cursor magnetic snapping", isCompleted: false),
                NoteItem(text: "Polish over-dock slide shelf animations", isCompleted: false)
            ],
            width: 300,
            height: 450,
            timerDuration: 25 * 60,
            timeRemaining: 25 * 60,
            isTimerRunning: false
        )
        
        let card2 = NoteCard(
            cardType: .tasks,
            title: "Launch Checklist",
            headerImagePath: w2,
            items: [
                NoteItem(text: "Finalize macOS AppIcon & Dock integration", isCompleted: true),
                NoteItem(text: "Verify template menu bar icon optical height", isCompleted: true),
                NoteItem(text: "Test slide-up drawer over sticky dock", isCompleted: true),
                NoteItem(text: "Render 4K UI widget showcase mockups", isCompleted: true),
                NoteItem(text: "Ship v1.0.0 release build to GitHub", isCompleted: false)
            ],
            width: 300,
            height: 450,
            timerDuration: 25 * 60,
            timeRemaining: 25 * 60,
            isTimerRunning: false
        )
        
        let strategyContent = "**Core Architecture Principles**\n\n• **Zero-Latency Spatial Physics**: Native AppKit NSPanel windows with hardware acceleration.\n\n• **Dynamic Visual Cohesion**: Background-aware chromatic adaptation.\n\n• **Spatial Canvas Freedom**: Independent movable widgets with magnetic snapping."
        
        let card3 = NoteCard(
            cardType: .notes,
            title: "Strategy & Notes",
            noteContent: strategyContent,
            pages: [
                NotePage(title: "Strategy", content: strategyContent),
                NotePage(title: "Ideas", content: "• Voice transcription widgets\n• Local vector DB embeddings for semantic recall"),
                NotePage(title: "Snippets", content: "```swift\nlet window = NSPanel(...)\n```")
            ],
            activePageIndex: 0,
            headerImagePath: w3,
            items: [],
            width: 360,
            height: 450
        )
        
        let card4 = NoteCard(
            cardType: .tasks,
            title: "Daily Focus",
            headerImagePath: w4,
            items: [
                NoteItem(text: "Review Q3 product roadmap & milestones", isCompleted: true),
                NoteItem(text: "Design system component tokens alignment", isCompleted: true),
                NoteItem(text: "Refactor local semantic AI search index", isCompleted: false),
                NoteItem(text: "Benchmark energy efficiency on Apple Silicon", isCompleted: false)
            ],
            width: 300,
            height: 450,
            timerDuration: 25 * 60,
            timeRemaining: 14 * 60 + 28,
            isTimerRunning: true
        )
        
        let card5 = NoteCard(
            cardType: .finder,
            title: "notskyai",
            headerImagePath: w1,
            items: [],
            width: 360,
            height: 460
        )
        
        let targets: [(String, NoteCard)] = [
            ("Notsky-Design-Iterations.png", card1),
            ("Notsky-Launch-Checklist.png", card2),
            ("Notsky-Strategy.png", card3),
            ("Notsky-Daily-Focus.png", card4),
            ("Notsky-AI-Finder.png", card5)
        ]
        
        for (filename, note) in targets {
            if let (_, pngData) = CardImageExporter.render4KPNGData(note: note, isDark: true) {
                let fileURL = docsDir.appendingPathComponent(filename)
                try? pngData.write(to: fileURL, options: .atomic)
                print("Successfully generated: \(fileURL.path)")
            }
        }
    }
}

@main
struct NotskyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = WidgetWindowManager.shared
    @StateObject private var pomodoro = PomodoroManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            Image(nsImage: MenuBarIconManager.shared.menuBarIcon)
        }
    }
}

struct MenuBarContentView: View {
    @ObservedObject private var manager = WidgetWindowManager.shared

    var body: some View {
        Button("New Task Group Card") {
            manager.spawnNewWidget()
        }
        .keyboardShortcut("n", modifiers: [.command])

        Button("New Freeform Note Card") {
            manager.spawnNewFreeformNoteWidget()
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Divider()

        Button("Clear Workspace") {
            manager.clearWorkspace()
        }

        Divider()

        Button("Check for Updates...") {
            SettingsWindowManager.shared.showSettings(item: .about)
            Task {
                await UpdateManager.shared.checkForUpdates()
            }
        }

        Button("Settings...") {
            SettingsWindowManager.shared.showSettings(item: .general)
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit Notsky") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
    }
}


