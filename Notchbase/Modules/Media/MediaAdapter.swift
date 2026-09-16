import AppKit

protocol MediaAdapter: AnyObject {
    var source: NowPlaying.Source { get }
    var bundleID: String { get }
    var notificationName: String { get }

    var isRunning: Bool { get }
    func snapshot() -> NowPlaying?
    func upNext() -> [QueueEntry]
    func play(_ entry: QueueEntry)
    func setShuffle(_ enabled: Bool)
    func setRepeat(_ mode: RepeatMode)
    func activate()
    func artwork(for playing: NowPlaying) async -> NSImage?
    func setFavorite(_ value: Bool)

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
    func setFavorite(_ value: Bool) {}
}

struct QueueEntry: Identifiable, Hashable {
    let id: Int
    var title: String
    var artist: String
    var artworkURL: URL?
    var handle: String?
    var contextURI: String?
}

enum SnapshotParser {
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
            repeatMode: fields.count >= 9 ? repeatMode(fields[8]) : .off,
            isFavorite: fields.count >= 10 && !fields[9].isEmpty ? fields[9] == "true" : nil
        )
    }
}
