# Changelog

## [1.0.3] - 2026-09-23

### What's Changed
- **DMG Installer Distribution**: Added packaged `.dmg` disk image with drag-and-drop `/Applications` shortcut for instant, seamless macOS installation.
- **Native macOS Settings Architecture**: Re-engineered using AppKit `NSSplitViewController` + unified `NSToolbar` with `sidebarTrackingSeparator` for authentic macOS appearance.
- **Stock macOS UI Components**: Standard sidebar navigation with SF Symbols & SF Pro typography, rounded inset grouped form cards, and instant search.
- **In-Place Demo Data Toggle**: On/off switch in Settings → General to populate or reset sample tasks, notes, and AI queries across default cards without closing them.
- **Stability & Lifecycle Fixes**: Disabled automatic AppKit termination so background widgets remain active without random exits.
- **Bundled Raycast Wallpapers**: Included built-in wallpaper collection inside the bundle with automated user library seeding.
