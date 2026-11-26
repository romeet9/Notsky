import Foundation

/// Spotlight file-name search for the assistant. Runs entirely off the main actor with a hard 2 second cap.
enum FileSearch {
    private static let skippedFragments = [
        "/Library/", "/node_modules/", "/.build/", "/.Trash/", "/.git/", "/DerivedData/", "/.cache/", "/Caches/"
    ]

    private static let unsafeToOpen: Set<String> = [
        "app", "command", "sh", "zsh", "bash", "tool", "pkg", "mpkg", "dmg", "workflow", "scpt", "scptd",
        "terminal", "action", "jar", "exe", "bat", "plugin", "kext", "prefpane", "webloc", "inetloc", "fileloc"
    ]

    static func isSafeToOpen(_ url: URL) -> Bool {
        !unsafeToOpen.contains(url.pathExtension.lowercased())
    }

    enum Kind: String { case any, file, folder }

    static func search(query: String, kind: Kind, limit: Int) async -> [FinderFileItem] {
        let term = query
            .replacingOccurrences(of: "\\", with: " ")
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "*", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        let capped = min(max(limit, 1), 10)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: run(term: term, kind: kind, limit: capped))
            }
        }
    }

    private static func run(term: String, kind: Kind, limit: Int) -> [FinderFileItem] {
        let words = term.split(separator: " ").map(String.init)
        var clauses = words.map { "kMDItemDisplayName == \"*\($0)*\"cd" }
        switch kind {
        case .any: break
        case .file: clauses.append("kMDItemContentType != \"public.folder\"")
        case .folder: clauses.append("kMDItemContentType == \"public.folder\"")
        }
        let predicate = clauses.joined(separator: " && ")
        let home = NSHomeDirectory()

        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("notsky-mdfind-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: outURL.path, contents: nil),
              let outHandle = try? FileHandle(forWritingTo: outURL) else { return [] }
        defer { try? FileManager.default.removeItem(at: outURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", home, predicate]
        process.standardOutput = outHandle
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { try? outHandle.close(); return [] }
        if finished.wait(timeout: .now() + 2) == .timedOut { process.terminate() }
        try? outHandle.close()

        guard let data = try? Data(contentsOf: outURL), let text = String(data: data, encoding: .utf8) else { return [] }
        let lowerTerm = term.lowercased()
        var candidates: [(path: String, name: String, date: Date, rank: Int)] = []
        for path in text.split(separator: "\n").prefix(2000).map(String.init) {
            if skippedFragments.contains(where: path.contains) { continue }
            let name = (path as NSString).lastPathComponent
            if name.hasPrefix(".") || path.contains("/.") { continue }
            let lowerName = name.lowercased()
            let rank = lowerName == lowerTerm ? 0 : (lowerName.hasPrefix(lowerTerm) ? 1 : 2)
            let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.contentModificationDateKey])
            candidates.append((path, name, values?.contentModificationDate ?? .distantPast, rank))
        }
        candidates.sort { $0.rank != $1.rank ? $0.rank < $1.rank : $0.date > $1.date }

        return candidates.prefix(limit).map { item in
            let url = URL(fileURLWithPath: item.path)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir)
            let size = isDir.boolValue ? "" : ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 }.map { Int64($0).formatted(.byteCount(style: .file)) } ?? "")
            return FinderFileItem(
                name: item.name,
                path: item.path,
                fileSize: size,
                fileType: isDir.boolValue ? "FOLDER" : url.pathExtension.uppercased(),
                summary: "",
                formattedDate: item.date == .distantPast ? "" : item.date.formatted(date: .abbreviated, time: .omitted)
            )
        }
    }
}
