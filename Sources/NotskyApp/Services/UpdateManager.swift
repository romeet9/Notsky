import SwiftUI
import AppKit
import Foundation

public struct GitHubReleaseInfo: Codable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String?
    public let assets: [GitHubReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

public struct GitHubReleaseAsset: Codable {
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

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
    }
    
    public var status: UpdateStatus = .idle
    public var lastCheckedDate: Date?
    
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.6"
    }
    
    private init() {}
    
    @MainActor
    public func checkForUpdates() async {
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
            self.lastCheckedDate = Date()
            
            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
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
            
            if filename.hasSuffix(".dmg") {
                let mountDir = tempDir.appendingPathComponent("mount")
                try FileManager.default.createDirectory(at: mountDir, withIntermediateDirectories: true)
                
                let attachProcess = Process()
                attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                attachProcess.arguments = ["attach", destFile.path, "-mountpoint", mountDir.path, "-nobrowse", "-readonly", "-quiet"]
                try attachProcess.run()
                attachProcess.waitUntilExit()
                
                let appInDmg = mountDir.appendingPathComponent("Notsky.app")
                if FileManager.default.fileExists(atPath: appInDmg.path) {
                    let stagedApp = tempDir.appendingPathComponent("Notsky.app")
                    try? FileManager.default.removeItem(at: stagedApp)
                    try FileManager.default.copyItem(at: appInDmg, to: stagedApp)
                    extractedAppPath = stagedApp.path
                }
                
                let detachProcess = Process()
                detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProcess.arguments = ["detach", mountDir.path, "-quiet"]
                try? detachProcess.run()
                detachProcess.waitUntilExit()
            } else if filename.hasSuffix(".zip") {
                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                unzipProcess.arguments = ["-xk", destFile.path, tempDir.path]
                try unzipProcess.run()
                unzipProcess.waitUntilExit()
                
                let appInZip = tempDir.appendingPathComponent("Notsky.app")
                if FileManager.default.fileExists(atPath: appInZip.path) {
                    extractedAppPath = appInZip.path
                }
            }
            
            guard let appPath = extractedAppPath else {
                status = .error("Failed to unpack Notsky.app from downloaded update.")
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
            rm -rf "/Applications/Notsky.app"
            cp -R "\(appPath)" "/Applications/Notsky.app"
            xattr -cr "/Applications/Notsky.app" 2>/dev/null || true
            open "/Applications/Notsky.app"
            """
            
            let scriptUrl = tempDir.appendingPathComponent("relaunch.sh")
            try relaunchScript.write(to: scriptUrl, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptUrl.path)
            
            let bgProcess = Process()
            bgProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
            bgProcess.arguments = [scriptUrl.path]
            try bgProcess.run()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
            
        } catch {
            status = .error("Installation error: \(error.localizedDescription)")
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
