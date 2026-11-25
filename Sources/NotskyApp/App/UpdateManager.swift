import SwiftUI
import AppKit
import Foundation

@Observable
public final class UpdateManager {
    public static let shared = UpdateManager()
    
    public enum UpdateStatus: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, notes: String, downloadUrl: URL)
        case downloading
        case installing
        case error(String)
        case managedManually
    }
    
    public var status: UpdateStatus = .idle
    public var lastCheckedDate: Date?
    
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.10"
    }
    
    /// Auto download/install is disabled in Notsky Next (updates are managed manually).
    public static let automaticUpdatesEnabled = false
    public static let managedManuallyMessage = String(localized: "Updates are managed manually in Notsky Next")

    private init() {}
    
    @MainActor
    public func checkForUpdates() async {
        // Notsky Next never talks to the Notsky release feed: installing that build would replace this app.
        guard Self.automaticUpdatesEnabled else {
            status = .managedManually
            return
        }
        status = .checking
        do {
            let url = URL(string: "https://api.github.com/repos/romeet9/Notsky/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("Notsky-App", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                status = .error("Could not fetch release info from GitHub")
                return
            }
            
            let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
            self.lastCheckedDate = Date.now
            
            let latestVersion = Self.stripLeadingV(release.tagName)
            
            if isVersionNewer(latest: latestVersion, current: currentVersion) {
                if let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) ?? release.assets.first(where: { $0.name.hasSuffix(".zip") }),
                   let assetUrl = URL(string: asset.browserDownloadUrl) {
                    status = .updateAvailable(version: release.tagName, notes: release.body ?? "", downloadUrl: assetUrl)
                } else if let html = release.htmlUrl, let fallbackUrl = URL(string: html) {
                    status = .updateAvailable(version: release.tagName, notes: release.body ?? "", downloadUrl: fallbackUrl)
                } else {
                    status = .upToDate
                }
            } else {
                status = .upToDate
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    public func downloadAndInstall(url: URL) async {
        guard Self.automaticUpdatesEnabled else {
            status = .managedManually
            return
        }
        status = .downloading
        
        do {
            let (tempLocalUrl, _) = try await URLSession.shared.download(from: url)
            status = .installing
            
            let filename = url.lastPathComponent
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let destFile = tempDir.appendingPathComponent(filename)
            try FileManager.default.moveItem(at: tempLocalUrl, to: destFile)
            
            var extractedAppPath: String?
            var mountedDir: URL?
            // Always detach the DMG, on every exit path.
            defer {
                if let mounted = mountedDir {
                    let detach = Process()
                    detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    detach.arguments = ["detach", mounted.path, "-quiet"]
                    try? detach.run()
                    detach.waitUntilExit()
                }
            }
            
            if filename.hasSuffix(".dmg") {
                let mountDir = tempDir.appendingPathComponent("mount")
                try FileManager.default.createDirectory(at: mountDir, withIntermediateDirectories: true)
                
                let attach = try await runTool("/usr/bin/hdiutil", ["attach", destFile.path, "-mountpoint", mountDir.path, "-nobrowse", "-readonly", "-quiet"])
                guard attach.status == 0 else {
                    status = .error("Could not mount the update disk image (hdiutil exit \(attach.status)).")
                    return
                }
                mountedDir = mountDir
                
                let appInDmg = mountDir.appendingPathComponent("Notsky.app")
                if FileManager.default.fileExists(atPath: appInDmg.path) {
                    let stagedApp = tempDir.appendingPathComponent("Notsky.app")
                    try? FileManager.default.removeItem(at: stagedApp)
                    try FileManager.default.copyItem(at: appInDmg, to: stagedApp)
                    extractedAppPath = stagedApp.path
                }
            } else if filename.hasSuffix(".zip") {
                let unzip = try await runTool("/usr/bin/ditto", ["-xk", destFile.path, tempDir.path])
                guard unzip.status == 0 else {
                    status = .error("Could not unpack the update archive (ditto exit \(unzip.status)).")
                    return
                }
                
                let appInZip = tempDir.appendingPathComponent("Notsky.app")
                if FileManager.default.fileExists(atPath: appInZip.path) {
                    extractedAppPath = appInZip.path
                }
            }
            
            guard let appPath = extractedAppPath else {
                status = .error("Failed to unpack Notsky.app from downloaded update.")
                return
            }
            
            // Integrity check (releases are ad-hoc signed, so no Team ID requirement).
            let verify = try await runTool("/usr/bin/codesign", ["--verify", "--deep", appPath])
            guard verify.status == 0 else {
                let detail = verify.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                status = .error("Downloaded app failed code signature verification (codesign exit \(verify.status)). \(detail)")
                return
            }
            
            // Remove quarantine from extracted app
            let xattrProcess = Process()
            xattrProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattrProcess.arguments = ["-cr", appPath]
            try? xattrProcess.run()
            xattrProcess.waitUntilExit()
            
            let relaunchScript = """
            sleep 1
            killall Notsky 2>/dev/null || true
            sleep 0.5
            rm -rf "/Applications/Notsky Next.app"
            cp -R "\(appPath)" "/Applications/Notsky Next.app"
            xattr -cr "/Applications/Notsky Next.app" 2>/dev/null || true
            open "/Applications/Notsky Next.app"
            """
            
            let scriptUrl = tempDir.appendingPathComponent("relaunch.sh")
            try relaunchScript.write(to: scriptUrl, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptUrl.path)
            
            let bgProcess = Process()
            bgProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
            bgProcess.arguments = [scriptUrl.path]
            try bgProcess.run()
            
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                NSApplication.shared.terminate(nil)
            }
            
        } catch {
            status = .error("Installation error: \(error.localizedDescription)")
        }
    }
    
    private static func stripLeadingV(_ tag: String) -> String {
        var trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        return trimmed
    }
    
    /// Runs a tool off the main thread and returns its exit status plus stderr.
    private nonisolated func runTool(_ path: String, _ arguments: [String]) async throws -> (status: Int32, stderr: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            let errPipe = Pipe()
            process.standardError = errPipe
            process.standardOutput = FileHandle.nullDevice
            process.terminationHandler = { finished in
                let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (finished.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func isVersionNewer(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(latestComponents.count, currentComponents.count) {
            let l = i < latestComponents.count ? latestComponents[i] : 0
            let c = i < currentComponents.count ? currentComponents[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}
