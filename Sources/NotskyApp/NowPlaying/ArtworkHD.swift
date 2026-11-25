import AppKit
import CryptoKit
import ImageIO

/// High-resolution album art lookup via the iTunes Search API, with memory + disk caching.
enum ArtworkHD {
    private static let memory = NSCache<NSString, NSImage>()
    private static let lock = NSLock()
    nonisolated(unsafe) private static var misses = Set<String>()

    /// Shorter pixel side of the image's best representation (never NSImage.size).
    static func shortSide(of image: NSImage) -> Int {
        var best = 0
        for rep in image.representations {
            let w = rep.pixelsWide, h = rep.pixelsHigh
            if w > 0, h > 0 { best = max(best, min(w, h)) }
        }
        if best > 0 { return best }
        var rect = CGRect(origin: .zero, size: image.size)
        if let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return min(cg.width, cg.height)
        }
        return 0
    }

    /// Returns an HD image for the track, or nil when nothing good was found.
    static func lookup(title: String, artist: String) async -> NSImage? {
        let candidates = queries(title: title, artist: artist)
        for c in candidates {
            if Task.isCancelled { return nil }
            if let img = await fetch(artist: c.artist, title: c.title) { return img }
        }
        return nil
    }

    // MARK: Query cleaning

    private static func clean(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: "\\([^)]*\\)|\\[[^\\]]*\\]|\\{[^}]*\\}", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\s+(ft\\.?|feat\\.?|featuring)\\s+.*$", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s*[|｜]\\s*.*$", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\s*-\\s*topic\\s*$", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func queries(title: String, artist: String) -> [(artist: String, title: String)] {
        var out: [(String, String)] = []
        let a = clean(artist)
        if let range = title.range(of: " - ") {
            let left = clean(String(title[..<range.lowerBound]))
            let right = clean(String(title[range.upperBound...]))
            if !left.isEmpty, !right.isEmpty {
                // "Title - Artist" when the right side is the known artist, else "Artist - Title".
                if !a.isEmpty, similarity(right, a) >= 0.6 {
                    out.append((a, left))
                } else if !a.isEmpty, similarity(left, a) >= 0.6 {
                    out.append((a, right))
                } else {
                    out.append((left, right))
                    out.append((right, left))
                }
            }
        }
        let t = clean(title)
        if !t.isEmpty { out.append((a, t)) }
        return out
    }

    // MARK: Matching

    private static func norm(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let mapped = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    private static func similarity(_ a: String, _ b: String) -> Double {
        let x = norm(a), y = norm(b)
        if x.isEmpty || y.isEmpty { return 0 }
        if x == y { return 1 }
        if x.contains(y) || y.contains(x) { return 0.85 }
        let sx = Set(x.split(separator: " ")), sy = Set(y.split(separator: " "))
        let union = sx.union(sy).count
        return union == 0 ? 0 : Double(sx.intersection(sy).count) / Double(union)
    }

    private struct Hit: Decodable {
        var trackName: String?
        var artistName: String?
        var artworkUrl100: String?
    }
    private struct Response: Decodable { var results: [Hit] }

    private static func best(_ hits: [Hit], artist: String, title: String) -> String? {
        var top: (score: Double, url: String)?
        for h in hits {
            guard let name = h.trackName, let url = h.artworkUrl100 else { continue }
            let ts = similarity(name, title)
            let artistScore = artist.isEmpty ? 1 : similarity(h.artistName ?? "", artist)
            guard ts >= 0.6, artistScore >= 0.5 else { continue }
            let score = ts * 2 + artistScore
            if top == nil || score > top!.score { top = (score, url) }
        }
        return top?.url
    }

    // MARK: Fetch + cache

    private static func fetch(artist: String, title: String) async -> NSImage? {
        let query = [artist, title].filter { !$0.isEmpty }.joined(separator: " ")
        guard !query.isEmpty else { return nil }
        let hash = SHA256.hash(data: Data(query.lowercased().utf8)).map { String(format: "%02x", $0) }.joined()
        if let m = memory.object(forKey: hash as NSString) { return m }
        lock.lock(); let known = misses.contains(hash); lock.unlock()
        if known { return nil }

        let dir = cacheDir()
        let file = dir.appendingPathComponent("\(hash).jpg")
        if let data = try? Data(contentsOf: file), let img = decode(data) {
            memory.setObject(img, forKey: hash as NSString)
            return img
        }

        var comps = URLComponents(string: "https://itunes.apple.com/search")!
        comps.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let searchURL = comps.url,
              let (data, _) = try? await URLSession.shared.data(for: request(searchURL)),
              let resp = try? JSONDecoder().decode(Response.self, from: data),
              let base = best(resp.results, artist: artist, title: title) else {
            if !Task.isCancelled { markMiss(hash) }
            return nil
        }
        for size in ["3000x3000bb", "1200x1200bb"] {
            if Task.isCancelled { return nil }
            let urlString = base.replacingOccurrences(of: "100x100bb", with: size)
            guard let url = URL(string: urlString),
                  let (bytes, response) = try? await URLSession.shared.data(for: request(url)),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let img = decode(bytes) else { continue }
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? bytes.write(to: file, options: .atomic)
            memory.setObject(img, forKey: hash as NSString)
            return img
        }
        if !Task.isCancelled { markMiss(hash) }
        return nil
    }

    private static func markMiss(_ hash: String) {
        lock.lock(); misses.insert(hash); lock.unlock()
    }

    private static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("Notsky", forHTTPHeaderField: "User-Agent")
        r.timeoutInterval = 20
        return r
    }

    private static func cacheDir() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches")
        return base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.romeet.notsky")
            .appendingPathComponent("artwork")
    }

    /// Fully decodes off the main thread so rendering never pays for it.
    private static func decode(_ data: Data) -> NSImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              cg.width > 0 else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
