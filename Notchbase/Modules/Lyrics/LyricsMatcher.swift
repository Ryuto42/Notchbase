import Foundation

struct LyricsCandidate {
    enum Source: String {
        case lrclib, netease
    }

    var source: Source
    var title: String
    var artists: [String]
    var duration: Double?
    var synced: String?
    var plain: String?
    var instrumental = false

    var hasSynced: Bool { synced?.isEmpty == false }
    var hasPlain: Bool { plain?.isEmpty == false }
}

enum LyricsMatcher {
    static func best(of candidates: [LyricsCandidate], for playing: NowPlaying) -> LyricsCandidate? {
        candidates
            .compactMap { candidate in score(candidate, for: playing).map { (candidate, $0) } }
            .max { $0.1 < $1.1 }?
            .0
    }

    static func matches(title: String, artists: [String], duration: Double?, for playing: NowPlaying) -> Bool {
        artistMatches(artists, playing.artist) && titleScore(title, playing.title) > 0
            && durationGap(duration, playing.duration).map { $0 <= maxGap } ?? true
    }

    static func durationGap(_ duration: Double?, _ target: Double) -> Double? {
        guard let duration, duration > 0, target > 0 else { return nil }
        return abs(duration - target)
    }

    private static let maxGap: Double = 20

    private static func score(_ candidate: LyricsCandidate, for playing: NowPlaying) -> Double? {
        guard candidate.hasSynced || candidate.hasPlain || candidate.instrumental,
              artistMatches(candidate.artists, playing.artist) else { return nil }
        let title = titleScore(candidate.title, playing.title)
        guard title > 0 else { return nil }

        var total = 100 + title * 30
        if let gap = durationGap(candidate.duration, playing.duration) {
            guard gap <= maxGap else { return nil }
            total += max(0, 15 - gap)
        }
        if candidate.hasSynced {
            total += 60
        } else if candidate.hasPlain {
            total += 10
        }
        if candidate.source == .lrclib { total += 1 }
        return total
    }

    private static func artistMatches(_ candidates: [String], _ artist: String) -> Bool {
        let wanted = split(artist)
        let offered = candidates.flatMap(split)
        return wanted.contains { want in
            offered.contains { have in
                have == want || (min(have.count, want.count) >= 2 && (have.contains(want) || want.contains(have)))
            }
        }
    }

    private static func titleScore(_ candidate: String, _ title: String) -> Double {
        let a = normalize(candidate), b = normalize(title)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a == b { return 1 }
        let coreA = normalize(core(candidate)), coreB = normalize(core(title))
        if !coreA.isEmpty, coreA == coreB { return 0.9 }
        if min(coreA.count, coreB.count) >= 2, coreA.contains(coreB) || coreB.contains(coreA) { return 0.6 }
        return 0
    }

    private static func split(_ artist: String) -> [String] {
        let separators = [",", "，", "、", "&", "＆", "/", "／", ";", "×", " x ", " feat. ", " feat ", " ft. ", " with ", " and "]
        var parts = [artist.lowercased()]
        for separator in separators {
            parts = parts.flatMap { $0.components(separatedBy: separator) }
        }
        return parts.map(normalize).filter { !$0.isEmpty }
    }

    private static func core(_ title: String) -> String {
        var text = title
        for (open, close) in [("(", ")"), ("（", "）"), ("[", "]"), ("【", "】"), ("〔", "〕")] {
            while let start = text.range(of: open), let end = text.range(of: close, range: start.upperBound..<text.endIndex) {
                text.removeSubrange(start.lowerBound..<end.upperBound)
            }
        }
        for marker in [" - ", " – ", " — ", "- ", " feat.", " ft."] {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                text = String(text[..<range.lowerBound])
            }
        }
        return text
    }

    static func normalize(_ text: String) -> String {
        var folded = text.precomposedStringWithCompatibilityMapping.lowercased()
        folded = folded.applyingTransform(StringTransform(rawValue: "Hant-Hans"), reverse: false) ?? folded
        let kept = CharacterSet.letters.union(.decimalDigits)
        return String(folded.unicodeScalars.filter { kept.contains($0) }.map(Character.init))
    }
}
