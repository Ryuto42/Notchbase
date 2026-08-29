import AppKit

enum RepeatMode: String, Equatable {
    case off, one, all

    var symbol: String {
        switch self {
        case .off, .all: "repeat"
        case .one: "repeat.1"
        }
    }
}

struct NowPlaying: Equatable {
    enum Source: String, Equatable {
        case music = "Music"
        case spotify = "Spotify"
    }

    var source: Source
    var isPlaying: Bool
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var artworkURL: URL?
    var isShuffling: Bool = false
    var repeatMode: RepeatMode = .off

    /// Identity of the track, used for artwork and lyrics caching.
    var trackKey: String { "\(source.rawValue)|\(artist)|\(title)|\(album)" }

    var progress: Double {
        duration > 0 ? min(1, max(0, position / duration)) : 0
    }
}
