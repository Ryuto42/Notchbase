import Foundation
import Observation
import CryptoKit

/// Fetches and caches lyrics per track, and maps the playhead onto the current line.
@Observable
final class LyricsController {
    enum Status: Equatable {
        case idle, loading, synced, plainOnly, instrumental, notFound
    }

    private(set) var status: Status = .idle
    private(set) var lines: [LyricLine] = []
    private(set) var plain: String?

    func applyDemo(_ demo: [LyricLine]) {
        lines = demo
        status = .synced
    }

    @ObservationIgnored private let client = LrclibClient()
    @ObservationIgnored private let cacheDir = Paths.directory("Lyrics")
    @ObservationIgnored private var loadingKey: String?

    private struct Cached: Codable {
        var lines: [LyricLine]
        var plain: String?
        var instrumental: Bool
    }

    func update(for playing: NowPlaying?) {
        guard Preferences.shared.lyricsEnabled, let playing, !playing.title.isEmpty else {
            reset()
            return
        }
        let key = playing.trackKey
        guard key != loadingKey else { return }
        loadingKey = key

        if let cached = JSONStore.load(Cached.self, from: cacheURL(key)) {
            apply(cached)
            return
        }

        lines = []
        plain = nil
        status = .loading

        Task { [weak self] in
            guard let self else { return }
            let response = await client.lyrics(for: playing)
            guard self.loadingKey == key else { return }

            let cached = Cached(
                lines: LrcParser.parse(response?.syncedLyrics ?? ""),
                plain: response?.plainLyrics,
                instrumental: response?.instrumental ?? false
            )
            if response != nil {
                JSONStore.save(cached, to: self.cacheURL(key))
            }
            self.apply(cached)
        }
    }

    /// Where the playhead sits between lines, as a fractional line number. Scrolling by this
    /// instead of by whole lines is what makes the column glide rather than jump.
    func progress(at position: Double) -> Double {
        guard !lines.isEmpty else { return 0 }
        guard let index = index(at: position) else { return 0 }
        let time = position + Preferences.shared.lyricsOffset
        let start = lines[index].time
        let end = index + 1 < lines.count ? lines[index + 1].time : start + 4
        let span = max(0.3, end - start)
        let through = min(1, max(0, (time - start) / span))
        // Hold the line for most of its duration, then travel to the next one.
        let travel = through < 0.7 ? 0 : (through - 0.7) / 0.3
        return Double(index) + travel
    }

    /// Index of the line that should be highlighted, honouring the user's offset.
    func index(at position: Double) -> Int? {
        guard !lines.isEmpty else { return nil }
        let time = position + Preferences.shared.lyricsOffset
        guard let first = lines.first, time >= first.time else { return nil }
        var low = 0
        var high = lines.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lines[mid].time <= time { low = mid } else { high = mid - 1 }
        }
        return low
    }

    private func apply(_ cached: Cached) {
        lines = cached.lines
        plain = cached.plain
        if cached.instrumental {
            status = .instrumental
        } else if !cached.lines.isEmpty {
            status = .synced
        } else if let plain = cached.plain, !plain.isEmpty {
            status = .plainOnly
        } else {
            status = .notFound
        }
    }

    private func reset() {
        loadingKey = nil
        lines = []
        plain = nil
        status = .idle
    }

    private func cacheURL(_ key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent("\(name)-v2.json")
    }
}
