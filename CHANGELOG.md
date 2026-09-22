# Changelog

## [1.0.6] - 2026-09-23

### What's Changed
- **Automatic GitHub In-App Updates**: Check for new releases directly within Settings or the Menu Bar, with one-click automatic download, installation, and relaunch.
- **Process Stability & DMG Fix**: Fixed accidental termination when launching from mounted DMG volumes; auto-installs to `/Applications` smoothly.
- **Enhanced Settings UI**: Real-time update checking status and release notes viewer in Settings → About.

## [1.0.5] - 2026-09-23

### What's Changed
- **Demo Data Off by Default**: Clean workspace on initial launch with 4 blank default cards (2 task groups, 1 note card, 1 AI Finder card).
- **In-Place Demo Data Toggle**: Turn on at any time in Settings → General to preview sample tasks, strategy notes, and search queries, or turn off to return to a clean slate.
- **Lightweight 17 MB DMG Installer**: Packaged `.dmg` disk image with drag-and-drop `/Applications` shortcut.
- **Native macOS Settings Architecture**: AppKit `NSSplitViewController` + unified `NSToolbar` with `sidebarTrackingSeparator`.
- **Stability Fixes**: Disabled automatic AppKit termination so background widgets stay persistent on your desktop.

---

### Note for First Launch on macOS
Because Notsky is an independent open-source application:
1. Drag **Notsky** to **Applications** from the DMG.
2. If macOS Gatekeeper shows a security prompt on first launch, **Right-Click (Control-Click) Notsky** in `/Applications` → click **Open** → click **Open** in the confirmation dialog.
3. Or run `xattr -cr /Applications/Notsky.app` in Terminal to clear the download quarantine flag.
