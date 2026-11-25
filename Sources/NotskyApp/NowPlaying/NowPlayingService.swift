import SwiftUI
import AppKit

public enum NowPlayingSource: String, Equatable {
    case music
    case spotify

    var displayName: String { self == .music ? "Music" : "Spotify" }
    var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
    var appleScriptName: String { displayName }
}

/// Single shared service for Now Playing. The primary source is the bundled mediaremote-adapter
/// (system-wide, like Control Center: browsers, Music, Spotify, any app). If the adapter files are
/// missing or the process keeps failing, it falls back to AppleScript for Music / Spotify,
/// querying only apps that are already running.
@MainActor
@Observable
public final class NowPlayingService {
    public static let shared = NowPlayingService()

    public private(set) var source: NowPlayingSource? = nil
    public private(set) var title: String = ""
    public private(set) var artist: String = ""
    public private(set) var album: String = ""
    public private(set) var duration: TimeInterval = 0
    public private(set) var isPlaying: Bool = false
    public private(set) var artwork: NSImage? = nil
    /// The app whose Automation permission was denied (AppleScript error -1743), if any.
    public private(set) var permissionDeniedSource: NowPlayingSource? = nil
    /// Bundle id of the app that is playing (adapter or AppleScript source).
    public private(set) var sourceBundleID: String? = nil
    /// Localized display name of the playing app.
    public private(set) var sourceName: String? = nil
    /// Small icon of the playing app.
    public private(set) var sourceIcon: NSImage? = nil
    /// True when a player is open and has a current track.
    public var hasTrack: Bool { sourceBundleID != nil && !title.isEmpty }

    @ObservationIgnored private var samplePosition: TimeInterval = 0
    @ObservationIgnored private var sampleDate: Date = Date()
    @ObservationIgnored private var playbackRate: Double = 1
    @ObservationIgnored private var sourceParentID: String? = nil
    @ObservationIgnored private var fallbackRunning = false
    @ObservationIgnored private var adapterMode = false
    @ObservationIgnored private var adapterRes: URL? = nil
    @ObservationIgnored private var adapterStream: AdapterStream? = nil
    @ObservationIgnored private var adapterGeneration = 0
    @ObservationIgnored private var adapterFailures = 0
    @ObservationIgnored private var artworkVersion = -1
    /// True once the adapter is delivering data; controls then go through it.
    private var adapterLive: Bool { adapterMode && adapterRes != nil }

    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var visibleViewCount = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var isPolling = false
    @ObservationIgnored private var epoch = 0
    @ObservationIgnored private var trackKey = ""
    @ObservationIgnored private var lastSource: NowPlayingSource? = nil
    private var artworkTask: Task<Void, Never>?
    @ObservationIgnored private var hdTask: Task<Void, Never>?
    @ObservationIgnored private var hdKey = ""
    @ObservationIgnored private var hdImage: NSImage? = nil
    @ObservationIgnored private let artworkCache = NSCache<NSString, NSImage>()
    @ObservationIgnored private let scriptQueue = DispatchQueue(label: "com.notsky.nowplaying.applescript", qos: .userInitiated)

    private init() {}

    // MARK: - Lifecycle

    /// Starts or stops the service depending on whether any music widget exists.
    /// The MediaRemote adapter is the primary source; AppleScript polling is only used
    /// when the adapter files are missing or the adapter process keeps failing.
    public func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            if let res = Self.adapterResources() {
                adapterRes = res
                adapterFailures = 0
                startAdapter()
            } else {
                startFallback()
            }
        } else {
            stopAdapter()
            stopFallback()
            adapterRes = nil
            clearState()
        }
    }

    public func viewDidAppear() {
        visibleViewCount += 1
        updateTimer()
        refresh()
    }

    public func viewDidDisappear() {
        visibleViewCount = max(0, visibleViewCount - 1)
        updateTimer()
    }

    private func updateTimer() {
        let shouldRun = isActive && fallbackRunning && visibleViewCount > 0
        if shouldRun, timer == nil {
            let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        } else if !shouldRun {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: - AppleScript fallback lifecycle

    private func startFallback() {
        guard !fallbackRunning else { return }
        fallbackRunning = true
        adapterMode = false
        let center = DistributedNotificationCenter.default()
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            observers.append(token)
        }
        updateTimer()
        refresh()
    }

    private func stopFallback() {
        guard fallbackRunning else { return }
        fallbackRunning = false
        epoch += 1
        let center = DistributedNotificationCenter.default()
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
        updateTimer()
    }

    // MARK: - MediaRemote adapter

    private nonisolated static func adapterResources() -> URL? {
        var candidates: [URL] = []
        if let r = Bundle.main.resourceURL { candidates.append(r.appendingPathComponent("MediaRemoteAdapter")) }
        candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/MediaRemoteAdapter"))
        let fm = FileManager.default
        return candidates.first {
            fm.fileExists(atPath: $0.appendingPathComponent("mediaremote-adapter.pl").path)
                && fm.fileExists(atPath: $0.appendingPathComponent("MediaRemoteAdapter.framework").path)
        }
    }

    private func startAdapter() {
        guard isActive, adapterStream == nil, let res = adapterRes else { return }
        adapterGeneration += 1
        let gen = adapterGeneration
        let started = Date()
        let stream = AdapterStream(res: res)
        stream.onSnapshot = { snap in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { NowPlayingService.shared.applyAdapter(snap, gen: gen) }
            }
        }
        stream.onExit = { _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    NowPlayingService.shared.adapterExited(gen: gen, ranFor: Date().timeIntervalSince(started))
                }
            }
        }
        do {
            try stream.start()
            adapterStream = stream
        } catch {
            adapterExited(gen: gen, ranFor: 0)
        }
    }

    private func stopAdapter() {
        adapterGeneration += 1
        adapterStream?.stop()
        adapterStream = nil
        adapterMode = false
    }

    private func adapterExited(gen: Int, ranFor: TimeInterval) {
        guard gen == adapterGeneration, isActive else { return }
        adapterStream = nil
        adapterMode = false
        adapterFailures = ranFor >= 10 ? 1 : adapterFailures + 1
        if adapterFailures >= 3 {
            adapterRes = nil
            clearState()
            startFallback()
            return
        }
        let delay = min(30.0, pow(2.0, Double(adapterFailures)))
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, self.isActive, self.adapterGeneration == gen, self.adapterStream == nil else { return }
            self.startAdapter()
        }
    }

    private func applyAdapter(_ snap: AdapterSnapshot, gen: Int) {
        guard isActive, gen == adapterGeneration else { return }
        adapterMode = true
        adapterFailures = 0
        permissionDeniedSource = nil
        source = nil
        guard snap.hasMedia, let bid = snap.bundleID else {
            clearState()
            return
        }
        if bid != sourceBundleID { resolveSource(bundleID: bid, parentID: snap.parentBundleID) }
        isPlaying = snap.playing
        title = snap.title
        artist = snap.artist
        album = snap.album
        duration = snap.duration
        let now = Date()
        var pos = snap.elapsed
        if snap.playing, let ts = snap.timestamp { pos += max(0, now.timeIntervalSince(ts)) * snap.rate }
        samplePosition = pos
        sampleDate = now
        playbackRate = snap.rate > 0 ? snap.rate : 1

        let key = "\(bid)|\(snap.title)|\(snap.artist)|\(snap.album)"
        let keyChanged = key != trackKey
        if keyChanged {
            trackKey = key
            hdTask?.cancel(); hdKey = ""; hdImage = nil
            if snap.artworkData == nil { artwork = artworkCache.object(forKey: key as NSString) }
        }
        if let data = snap.artworkData {
            if snap.artworkVersion != artworkVersion || artwork == nil || keyChanged {
                artworkVersion = snap.artworkVersion
                // New artwork bytes always win over the cache: browsers often send their app icon
                // first and the real thumbnail a moment later for the same track.
                if let image = NSImage(data: data) {
                    artworkCache.setObject(image, forKey: key as NSString)
                    artwork = image
                } else if let cached = artworkCache.object(forKey: key as NSString) {
                    artwork = cached
                }
            }
        } else if keyChanged == false, snap.artworkVersion != artworkVersion {
            artworkVersion = snap.artworkVersion
            artwork = nil
        }
        finalizeArtwork(key: key)
    }

    private func resolveSource(bundleID: String, parentID: String?) {
        sourceBundleID = bundleID
        sourceParentID = parentID
        let ids = [bundleID] + (parentID.map { [$0] } ?? [])
        for id in ids {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                var name = FileManager.default.displayName(atPath: url.path)
                if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
                sourceName = name
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 16, height: 16)
                sourceIcon = icon
                return
            }
        }
        sourceName = bundleID.split(separator: ".").last.map { String($0).capitalized } ?? bundleID
        sourceIcon = nil
    }

    /// Brings the app that is currently playing to the front.
    public func activateSource() {
        guard let bid = sourceBundleID else { return }
        let ids = [bid] + (sourceParentID.map { [$0] } ?? [])
        for id in ids {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                app.activate()
                return
            }
        }
        for id in ids {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
    }

    private nonisolated static func sendAdapter(_ res: URL, _ args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            p.arguments = [res.appendingPathComponent("mediaremote-adapter.pl").path,
                           res.appendingPathComponent("MediaRemoteAdapter.framework").path] + args
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }

    private func adapterSend(_ commandID: Int) {
        guard let res = adapterRes else { return }
        Self.sendAdapter(res, ["send", "--force", String(commandID)])
    }

    private func clearState() {
        source = nil
        sourceBundleID = nil
        sourceParentID = nil
        sourceName = nil
        sourceIcon = nil
        title = ""
        artist = ""
        album = ""
        duration = 0
        isPlaying = false
        artwork = nil
        trackKey = ""
        artworkVersion = -1
        artworkTask?.cancel()
        hdTask?.cancel(); hdKey = ""; hdImage = nil
    }

    // MARK: - Progress

    /// Local interpolation between updates.
    public func position(at date: Date) -> TimeInterval {
        guard isPlaying else { return min(samplePosition, max(duration, samplePosition)) }
        let value = samplePosition + date.timeIntervalSince(sampleDate) * playbackRate
        return duration > 0 ? min(max(0, value), duration) : max(0, value)
    }

    // MARK: - Polling

    private struct Snapshot: Sendable {
        var source: NowPlayingSource
        var isPlaying: Bool
        var title: String
        var artist: String
        var album: String
        var duration: TimeInterval
        var position: TimeInterval
        var artworkURL: String?
    }

    private struct PollResult: Sendable {
        var snapshots: [Snapshot]
        var denied: NowPlayingSource?
    }

    public func refresh() {
        guard isActive, fallbackRunning, !isPolling else { return }
        isPolling = true
        let startEpoch = epoch
        let sources = [NowPlayingSource.music, .spotify].filter { Self.isRunning($0) }
        let queue = scriptQueue
        Task.detached(priority: .userInitiated) {
            let result: PollResult = await withCheckedContinuation { cont in
                queue.async {
                    var snaps: [Snapshot] = []
                    var denied: NowPlayingSource? = nil
                    for source in sources {
                        switch Self.query(source) {
                        case .success(let snap): if let snap { snaps.append(snap) }
                        case .denied: denied = source
                        case .failure: break
                        }
                    }
                    cont.resume(returning: PollResult(snapshots: snaps, denied: denied))
                }
            }
            await MainActor.run {
                NowPlayingService.shared.isPolling = false
                guard NowPlayingService.shared.epoch == startEpoch else { return }
                NowPlayingService.shared.apply(result)
            }
        }
    }

    private func apply(_ result: PollResult) {
        guard isActive, fallbackRunning else { return }
        permissionDeniedSource = result.denied
        let playing = result.snapshots.first(where: { $0.isPlaying })
        let paused = result.snapshots.first(where: { $0.source == lastSource }) ?? result.snapshots.first
        guard let snap = playing ?? paused else {
            if source != nil { clearState() }
            return
        }
        lastSource = snap.source
        source = snap.source
        if sourceBundleID != snap.source.bundleID { resolveSource(bundleID: snap.source.bundleID, parentID: nil) }
        playbackRate = 1
        isPlaying = snap.isPlaying
        title = snap.title
        artist = snap.artist
        album = snap.album
        duration = snap.duration
        samplePosition = snap.position
        sampleDate = Date()

        let key = "\(snap.source.rawValue)|\(snap.title)|\(snap.artist)|\(snap.album)"
        if key != trackKey {
            trackKey = key
            artwork = nil
            hdTask?.cancel(); hdKey = ""; hdImage = nil
            loadArtwork(for: snap, key: key)
        }
    }

    // MARK: - Controls

    public func togglePlayPause() {
        if adapterLive {
            samplePosition = position(at: Date())
            sampleDate = Date()
            isPlaying.toggle()
            adapterSend(2)
            return
        }
        guard let source else { return }
        epoch += 1
        samplePosition = position(at: Date())
        sampleDate = Date()
        isPlaying.toggle()
        run(source, "playpause")
    }

    public func nextTrack() {
        if adapterLive { adapterSend(4); return }
        guard let source else { return }
        epoch += 1
        run(source, "next track")
    }

    public func previousTrack() {
        if adapterLive { adapterSend(5); return }
        guard let source else { return }
        epoch += 1
        run(source, "previous track")
    }

    public func seek(to seconds: TimeInterval) {
        let clamped = max(0, min(seconds, duration > 0 ? duration : seconds))
        if adapterLive, let res = adapterRes {
            samplePosition = clamped
            sampleDate = Date()
            Self.sendAdapter(res, ["seek", String(Int(clamped * 1_000_000))])
            return
        }
        guard let source else { return }
        epoch += 1
        samplePosition = clamped
        sampleDate = Date()
        run(source, "set player position to \(String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), clamped))")
    }

    private func run(_ source: NowPlayingSource, _ command: String) {
        let script = "tell application \"\(source.appleScriptName)\" to \(command)"
        let queue = scriptQueue
        Task.detached(priority: .userInitiated) {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                queue.async {
                    _ = Self.execute(script)
                    cont.resume()
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run { NowPlayingService.shared.refresh() }
        }
    }

    public func openPlayer(_ source: NowPlayingSource = .music) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    public func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Artwork

    private func loadArtwork(for snap: Snapshot, key: String) {
        artworkTask?.cancel()
        let source = snap.source
        let urlString = snap.artworkURL
        if let urlString, let cached = artworkCache.object(forKey: urlString as NSString) {
            artwork = cached
            finalizeArtwork(key: key)
            return
        }
        let queue = scriptQueue
        artworkTask = Task { [weak self] in
            var image: NSImage? = nil
            if source == .music {
                let data: Data? = await withCheckedContinuation { cont in
                    queue.async { cont.resume(returning: Self.musicArtworkData()) }
                }
                if let data { image = NSImage(data: data) }
            } else if let urlString, let url = URL(string: urlString) {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    image = NSImage(data: data)
                    if let image { self?.artworkCache.setObject(image, forKey: urlString as NSString) }
                }
            }
            guard !Task.isCancelled, let self, self.trackKey == key else { return }
            self.artwork = image
            self.finalizeArtwork(key: key)
        }
    }

    /// Shows the HD art for the current track if known, otherwise starts the iTunes lookup when the
    /// current art is under 1000 px (or missing). The original art stays visible until HD arrives.
    private func finalizeArtwork(key: String) {
        guard key == trackKey else { return }
        if hdKey == key {
            if let hd = hdImage, artwork !== hd, ArtworkHD.shortSide(of: hd) > (artwork.map(ArtworkHD.shortSide) ?? 0) { artwork = hd }
            return
        }
        guard AppSettings.shared.highResArtwork else { return }
        if let art = artwork, ArtworkHD.shortSide(of: art) >= 1000 { return }
        hdKey = key
        hdTask?.cancel()
        let t = title, a = artist
        hdTask = Task { [weak self] in
            let img = await ArtworkHD.lookup(title: t, artist: a)
            guard !Task.isCancelled, let self, self.trackKey == key, let img else { return }
            self.hdImage = img
            if ArtworkHD.shortSide(of: img) > (self.artwork.map(ArtworkHD.shortSide) ?? 0) { self.artwork = img }
        }
    }

    // MARK: - AppleScript (runs on scriptQueue, never on main)

    private nonisolated static func isRunning(_ source: NowPlayingSource) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).isEmpty
    }

    private enum QueryOutcome {
        case success(Snapshot?)
        case denied
        case failure
    }

    private nonisolated static func execute(_ source: String) -> (NSAppleEventDescriptor?, Int?) {
        guard let script = NSAppleScript(source: source) else { return (nil, nil) }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            return (nil, (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? -1)
        }
        return (result, nil)
    }

    private nonisolated static func query(_ source: NowPlayingSource) -> QueryOutcome {
        let artworkLine = source == .spotify ? "set art to artwork url of t" : "set art to \"\""
        let durationExpr = source == .spotify ? "(duration of t) as integer" : "((duration of t) * 1000) as integer"
        let script = """
        tell application "\(source.appleScriptName)"
            if player state is stopped then return {"stopped"}
            set s to "paused"
            if player state is playing then set s to "playing"
            set t to current track
            \(artworkLine)
            return {s, name of t, artist of t, album of t, \(durationExpr), ((player position) * 1000) as integer, art}
        end tell
        """
        let (descriptor, errorCode) = execute(script)
        if errorCode == -1743 { return .denied }
        guard let descriptor, descriptor.numberOfItems >= 7 else {
            // Stopped (single item) or a non-permission error such as a track-less player.
            return errorCode == nil ? .success(nil) : .failure
        }
        func str(_ i: Int) -> String { descriptor.atIndex(i)?.stringValue ?? "" }
        func num(_ i: Int) -> Double { Double(descriptor.atIndex(i)?.int32Value ?? 0) / 1000.0 }
        let durationValue = source == .spotify ? Double(descriptor.atIndex(5)?.int32Value ?? 0) / 1000.0 : num(5)
        let art = str(7)
        return .success(Snapshot(
            source: source,
            isPlaying: str(1) == "playing",
            title: str(2),
            artist: str(3),
            album: str(4),
            duration: durationValue,
            position: num(6),
            artworkURL: art.isEmpty ? nil : art
        ))
    }

    private nonisolated static func musicArtworkData() -> Data? {
        let script = """
        tell application "Music"
            if (count of artworks of current track) is 0 then return ""
            return raw data of artwork 1 of current track
        end tell
        """
        let (descriptor, _) = execute(script)
        guard let descriptor else { return nil }
        let data = descriptor.data
        return data.count > 16 ? data : nil
    }
}

// MARK: - Adapter stream

struct AdapterSnapshot: Sendable {
    var bundleID: String?
    var parentBundleID: String?
    var title = ""
    var artist = ""
    var album = ""
    var duration: TimeInterval = 0
    var elapsed: TimeInterval = 0
    var timestamp: Date?
    var rate: Double = 1
    var playing = false
    var artworkData: Data?
    var artworkVersion = 0
    var hasMedia: Bool { bundleID != nil && !title.isEmpty }
}

/// Long-lived `mediaremote-adapter.pl stream` process. Parses newline-delimited JSON and merges
/// diffs on its own queue; callbacks fire off the main thread.
final class AdapterStream: @unchecked Sendable {
    var onSnapshot: (@Sendable (AdapterSnapshot) -> Void)?
    var onExit: (@Sendable (Int32) -> Void)?

    private let process = Process()
    private let pipe = Pipe()
    private let queue = DispatchQueue(label: "com.notsky.nowplaying.adapter", qos: .userInitiated)
    private var buffer = Data()
    private var state: [String: Any] = [:]
    private var artB64: String?
    private var artData: Data?
    private var artVersion = 0
    private var stopped = false
    private let plainDate = ISO8601DateFormatter()
    private let fracDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(res: URL) {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            res.appendingPathComponent("mediaremote-adapter.pl").path,
            res.appendingPathComponent("MediaRemoteAdapter.framework").path,
            "stream", "--debounce=100",
        ]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
    }

    func start() throws {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self else { handle.readabilityHandler = nil; return }
            if data.isEmpty { handle.readabilityHandler = nil; return }
            self.queue.async { self.consume(data) }
        }
        process.terminationHandler = { [weak self] p in
            guard let self else { return }
            self.queue.async {
                self.pipe.fileHandleForReading.readabilityHandler = nil
                if !self.stopped { self.onExit?(p.terminationStatus) }
            }
        }
        try process.run()
    }

    func stop() {
        queue.async { self.stopped = true }
        pipe.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
    }

    private func consume(_ data: Data) {
        guard !stopped else { return }
        buffer.append(data)
        while let nl = buffer.firstIndex(of: 10) {
            let line = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            if !line.isEmpty { handle(line) }
        }
    }

    private func handle(_ line: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = obj["payload"] as? [String: Any] else { return }
        let diff = obj["diff"] as? Bool ?? false
        if diff {
            for (k, v) in payload {
                if v is NSNull { state.removeValue(forKey: k) } else { state[k] = v }
            }
        } else {
            state = payload.filter { !($0.value is NSNull) }
        }
        if let b64 = state["artworkData"] as? String {
            if b64 != artB64 {
                artB64 = b64
                artData = Data(base64Encoded: b64, options: .ignoreUnknownCharacters)
                artVersion += 1
            }
        } else if artB64 != nil {
            artB64 = nil
            artData = nil
            artVersion += 1
        }
        var snap = AdapterSnapshot()
        snap.bundleID = state["bundleIdentifier"] as? String
        snap.parentBundleID = state["parentApplicationBundleIdentifier"] as? String
        snap.title = state["title"] as? String ?? ""
        snap.artist = state["artist"] as? String ?? ""
        snap.album = state["album"] as? String ?? ""
        snap.duration = (state["duration"] as? NSNumber)?.doubleValue ?? 0
        snap.elapsed = (state["elapsedTime"] as? NSNumber)?.doubleValue ?? 0
        snap.rate = (state["playbackRate"] as? NSNumber)?.doubleValue ?? 0
        snap.playing = (state["playing"] as? Bool) ?? (snap.rate > 0)
        if let ts = state["timestamp"] as? String {
            snap.timestamp = fracDate.date(from: ts) ?? plainDate.date(from: ts)
        }
        snap.artworkData = artData
        snap.artworkVersion = artVersion
        onSnapshot?(snap)
    }
}
