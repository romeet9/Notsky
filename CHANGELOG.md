# Changelog

## [1.0.4] - 2026-09-23

### What's Changed
- **97% Size Reduction (17 MB)**: Cleaned unused high-resolution assets and optimized bundled Raycast wallpapers for Retina displays, shrinking the installer from 475 MB down to ~17 MB.
- **DMG Installer with Drag & Drop**: Included packaged `.dmg` disk image with `/Applications` folder shortcut for simple installation.
- **macOS Gatekeeper Compatibility**: Cleaned ad-hoc code signature across all bundle frameworks.
- **Native macOS Settings Architecture**: AppKit `NSSplitViewController` + unified `NSToolbar` with `sidebarTrackingSeparator`.
- **In-Place Demo Data Reset**: Toggle in Settings → General populates or resets sample content across desktop cards without closing windows.

---

### Note for First Launch on macOS
Because Notsky is an independent open-source application:
1. Drag **Notsky** to **Applications** from the DMG.
2. If macOS Gatekeeper shows a security prompt on first launch, **Right-Click (Control-Click) Notsky** in `/Applications` → click **Open** → click **Open** in the confirmation dialog.
3. Or run `xattr -cr /Applications/Notsky.app` in Terminal to clear the download quarantine flag.
