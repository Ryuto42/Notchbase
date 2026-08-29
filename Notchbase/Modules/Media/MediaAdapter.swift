import AppKit

/// One controllable player. Adapters never touch an app that is not already running —
/// merely addressing it with `tell application` would launch it.
protocol MediaAdapter: AnyObject {
    var source: NowPlaying.Source { get }
    var bundleID: String { get }
    /// Distributed notification posted by the app when playback changes.
    var notificationName: String { get }

    var isRunning: Bool { get }
    func snapshot() -> NowPlaying?
    /// Tracks queued after the current one. Empty when the app exposes no queue.
    func upNext() -> [QueueEntry]
    /// Start the given queue entry.
    func play(_ entry: QueueEntry)
    func setShuffle(_ enabled: Bool)
    func setRepeat(_ mode: RepeatMode)
    /// Brings the player to the front.
    func activate()
    func artwork(for playing: NowPlaying) async -> NSImage?

    func playPause()
    func next()
    func previous()
    func seek(to seconds: Double)
}

extension MediaAdapter {
    var isRunning: Bool { NSRunningApplication.isRunning(bundleID: bundleID) }
    func upNext() -> [QueueEntry] { [] }
    func play(_ entry: QueueEntry) {}
    func setShuffle(_ enabled: Bool) {}
    func setRepeat(_ mode: RepeatMode) {}
    func activate() {}
}

struct QueueEntry: Identifiable, Hashable {
    let id: Int
    var title: String
    var artist: String
    var artworkURL: URL?
    /// Spotify: the track URI. Apple Music: its index in the current playlist.
    var handle: String?
    /// Spotify only: the album/playlist the queue belongs to, so playback keeps its context
    /// instead of collapsing to a single track.
    var contextURI: String?
}

/// Splits a tab-separated snapshot line into a `NowPlaying`.
enum SnapshotParser {
    /// Spotify reports a boolean, Apple Music an off/one/all enum.
    static func repeatMode(_ raw: String) -> RepeatMode {
        switch raw {
        case "true", "all": .all
        case "one": .one
        default: .off
        }
    }

    static func parse(_ raw: String, source: NowPlaying.Source, durationDivisor: Double) -> NowPlaying? {
        let fields = raw.components(separatedBy: "\t")
        guard fields.count >= 6 else { return nil }
        let state = fields[0]
        guard state == "playing" || state == "paused" else { return nil }
        return NowPlaying(
            source: source,
            isPlaying: state == "playing",
            title: fields[1],
            artist: fields[2],
            album: fields[3],
            duration: (Double(fields[4]) ?? 0) / durationDivisor,
            position: Double(fields[5]) ?? 0,
            artworkURL: fields.count >= 7 ? URL(string: fields[6]) : nil,
            isShuffling: fields.count >= 8 && fields[7] == "true",
            repeatMode: fields.count >= 9 ? repeatMode(fields[8]) : .off
        )
    }
}
