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
              artistMatches(candidate.artists, playing.artist),
              !isMixed(candidate) else { return nil }
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

    // 訳やローマ字が原文と交互・同じ時刻に入っている歌詞
    static func isMixed(_ candidate: LyricsCandidate) -> Bool {
        let texts: [String]
        if candidate.hasSynced {
            let lines = LrcParser.parse(candidate.synced ?? "").filter { !$0.text.isEmpty }
            let paired = zip(lines, lines.dropFirst()).filter { abs($0.time - $1.time) <= 0.05 && $0.text != $1.text }.count
            if lines.count >= 6, Double(paired) >= Double(lines.count) * 0.2 { return true }
            texts = lines.map(\.text)
        } else {
            texts = (candidate.plain ?? "").components(separatedBy: .newlines)
        }
        return isMixed(texts.map(script).filter { $0 != .none })
    }

    enum Script { case none, japanese, korean, chinese, latin }

    static func isMixed(_ scripts: [Script]) -> Bool {
        guard scripts.count >= 6 else { return false }
        let total = Double(scripts.count)
        func share(_ kind: Script) -> Double { Double(scripts.filter { $0 == kind }.count) / total }
        func count(_ kind: Script) -> Int { scripts.filter { $0 == kind }.count }
        let japanese = share(.japanese), korean = share(.korean), chinese = share(.chinese), latin = share(.latin)

        if japanese >= 0.25 {
            if (chinese >= 0.2 && count(.chinese) >= 3) || korean >= 0.1 { return true }
            let alternating = zip(scripts, scripts.dropFirst()).filter { $0 == .japanese && $1 == .latin }.count
            return latin >= 0.4 && Double(alternating) >= Double(count(.latin)) * 0.8
        }
        if korean >= 0.25 {
            return (chinese >= 0.2 && count(.chinese) >= 3) || japanese >= 0.15
        }
        if chinese > latin {
            return japanese >= 0.15 || korean >= 0.15
        }
        return japanese + korean + chinese >= 0.2
    }

    private static let chineseMarkers = Set("你们們这這么麼吗嗎吧呢说讓让给还时个为过没沒".unicodeScalars)

    static func script(_ line: String) -> Script {
        var kana = 0, hangul = 0, han = 0, latin = 0
        for scalar in line.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x30FF, 0x31F0...0x31FF, 0xFF66...0xFF9F: kana += 1
            case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F: hangul += 1
            case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF: han += 1
            case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F: latin += 1
            default: break
            }
        }
        if kana > 0 { return .japanese }
        if hangul > 0 { return .korean }
        if han >= 2 { return line.unicodeScalars.contains(where: chineseMarkers.contains) ? .chinese : .none }
        if latin >= 3 { return .latin }
        return .none
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
