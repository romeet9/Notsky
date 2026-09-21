<div align="center">

<img src="docs/screenshots/AppIcon.png" alt="Notsky Icon" width="124" height="124" style="border-radius: 28px; box-shadow: 0 12px 32px rgba(0,0,0,0.35);" />

# Notsky

### Liquid-Glass Spatial Notes and Local AI Workspace for macOS

<br />

[![macOS](https://img.shields.io/badge/macOS-14.0%2B_Sonoma%20%7C%20Sequoia-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI_Native-0071E3?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![Release](https://img.shields.io/github/v/release/romeet9/Notsky?style=for-the-badge&color=22C55E&logo=github)](https://github.com/romeet9/Notsky/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-gray?style=for-the-badge)](LICENSE)

<br />

<p align="center">
  Notsky transforms your macOS desktop into a tactile spatial canvas. It combines liquid-glass materials, magnetic multi-display snapping, integrated Pomodoro timers, and a local AI assistant that finds and summarizes documents directly from your screen.
</p>

<br />

</div>

https://github.com/user-attachments/assets/ba538de9-7584-4238-95df-bcfaf9edf732


---

## What is Notsky?

Notsky is an open-source native macOS desktop workspace application built entirely in Swift and SwiftUI. It replaces traditional static sticky notes with floating translucent cards featuring real-time wallpaper color sampling, multi-tab rich markdown editing, focus timers, and natural language local document search powered by `notskyai`.

---

## Download and Quick Install

Pre-compiled releases are available for macOS Sonoma (14.0+) and macOS Sequoia (15.0+):

<div align="center">
  <br />
  <a href="https://github.com/romeet9/Notsky/releases/latest">
    <img src="https://img.shields.io/badge/Download-Notsky_v1.0.0_macOS-0071E3?style=for-the-badge&logo=apple&logoColor=white" height="40" alt="Download Notsky for macOS" />
  </a>
  <br /><br />
</div>

1. Download **`Notsky-v1.0.0-macOS.zip`** from the [Latest Release](https://github.com/romeet9/Notsky/releases/latest).
2. Unzip and drag **`Notsky.app`** to your `/Applications` directory.
3. Open **Notsky** via Spotlight (`⌘ Space`) or Launchpad.

---

## Core Capabilities

### Liquid-Glass Depth
Built using Apple native `.ultraThinMaterial` with specular light borders. Notsky samples your desktop wallpaper in real time to balance text contrast and dynamically tint badges, checkboxes, and timers.

### Spatial Multi-Card Canvas
Create task lists with spring-animated strike-throughs, multi-tab notes with bold and bullet formatting, and floating scratchpads. Cards snap to 24 pt magnetic gutters across multiple monitors.

### notskyai Intelligent Assistant
A spotlight-style search interface that scans local files across your Mac. Query PDFs, spreadsheets, presentations, code, and images using natural phrases like *"find design assets from yesterday"* with instant file previews and AI summaries.

### Slide-Up Notes Shelf
Press `⌘⇧D` from anywhere to slide up a full-width frosted glass shelf directly over the macOS Dock. Review all active project cards in a single horizontal carousel without moving open app windows.

### Tactile Feedback Engine
Mechanical synthetic audio clicks and macOS Taptic Engine haptics provide physical confirmation whenever you complete a task, switch tabs, or cycle wallpaper packs.

---

## Architecture

Notsky is built as a pure Swift Package Manager project with zero third-party dependencies:

```
NotskyApp/
├── Package.swift                     # Swift Package Manager manifest
├── Sources/NotskyApp/
│   ├── App.swift                     # MenuBarExtra and lifecycle entry point
│   ├── Models/                       # AppSettings, NoteStore, WindowManager, Pomodoro
│   ├── Services/                     # AIFinderService, MenuBarIconManager
│   ├── Utils/                        # SensoryFeedback, NaturalDateParser, ImageDownsampler
│   └── Views/                        # NoteCardView, FreeformNoteCardView, FinderCardView, DrawerShelfView
└── Resources/                        # AppIcon.icns, Info.plist, MenuBarIcon template
```

---

## Building from Source

### Prerequisites
* macOS 14.0 or newer
* Xcode 15.0+ or Swift 6.0+ toolchain

```bash
# Clone the repository
git clone https://github.com/romeet9/Notsky.git
cd Notsky

# Compile release binary
swift build -c release

# Package and launch app
mkdir -p /Applications/Notsky.app/Contents/{MacOS,Resources}
cp .build/release/NotskyApp /Applications/Notsky.app/Contents/MacOS/Notsky
cp Resources/AppIcon.icns /Applications/Notsky.app/Contents/Resources/
cp Resources/MenuBarIcon*.png /Applications/Notsky.app/Contents/Resources/ || true
cp Resources/Info.plist /Applications/Notsky.app/Contents/Info.plist

open /Applications/Notsky.app
```

---

## Creator

Designed and built by **Romeet Chatterjee**

* **Portfolio**: [romeet-portfolio.vercel.app](https://romeet-portfolio.vercel.app)
* **GitHub**: [@romeet9](https://github.com/romeet9)
* **Twitter / X**: [@romeetchatterjee](https://x.com/romeetchatterjee)

---

<div align="center">
  <sub>Released under the MIT License. Designed for macOS.</sub>
</div>
