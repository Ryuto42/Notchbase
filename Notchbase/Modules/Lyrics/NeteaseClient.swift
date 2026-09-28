import Foundation

struct NeteaseClient {
    private struct SearchResponse: Decodable {
        struct Artist: Decodable {
            var name: String?
            var alias: [String]?
            var tns: [String]?
        }
        struct Song: Decodable {
            var id: Int
            var name: String
            var ar: [Artist]?
            var alia: [String]?
            var dt: Double?
        }
        struct Result: Decodable { var songs: [Song]? }
        var result: Result?
    }

    private struct LyricResponse: Decodable {
        struct Text: Decodable { var lyric: String? }
        var lrc: Text?
        var nolyric: Bool?
        var uncollected: Bool?
    }

    private let session = URLSession(configuration: .ephemeral)
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"

    func candidates(for playing: NowPlaying) async -> [LyricsCandidate] {
        var components = URLComponents(string: "https://music.163.com/api/cloudsearch/pc")!
        components.queryItems = [
            URLQueryItem(name: "s", value: "\(playing.title) \(playing.artist)"),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "12"),
        ]
        guard let songs = await fetch(components.url, as: SearchResponse.self)?.result?.songs else { return [] }

        let picked = songs
            .map { song in (song, artists(of: song), song.dt.map { $0 / 1000 }) }
            .filter { LyricsMatcher.matches(title: $0.0.name, artists: $0.1, duration: $0.2, for: playing) }
            .sorted {
                (LyricsMatcher.durationGap($0.2, playing.duration) ?? .infinity)
                    < (LyricsMatcher.durationGap($1.2, playing.duration) ?? .infinity)
            }
            .prefix(2)

        return await withTaskGroup(of: LyricsCandidate?.self) { group in
            for (song, artists, duration) in picked {
                group.addTask { await candidate(song: song, artists: artists, duration: duration) }
            }
            var found: [LyricsCandidate] = []
            for await candidate in group {
                if let candidate { found.append(candidate) }
            }
            return found
        }
    }

    private func artists(of song: SearchResponse.Song) -> [String] {
        (song.ar ?? []).flatMap { [$0.name].compactMap { $0 } + ($0.alias ?? []) + ($0.tns ?? []) }
    }

    private func candidate(song: SearchResponse.Song, artists: [String], duration: Double?) async -> LyricsCandidate? {
        var components = URLComponents(string: "https://music.163.com/api/song/lyric")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(song.id)),
            URLQueryItem(name: "lv", value: "1"),
        ]
        guard let response = await fetch(components.url, as: LyricResponse.self) else { return nil }
        let raw = response.lrc?.lyric ?? ""
        let instrumental = response.nolyric == true || raw.contains("纯音乐")
        let synced = Self.stripCredits(raw)
        guard instrumental || !synced.isEmpty else { return nil }
        return LyricsCandidate(source: .netease,
                               title: song.name,
                               artists: artists,
                               duration: duration,
                               synced: instrumental ? nil : synced,
                               plain: nil,
                               instrumental: instrumental)
    }

    private static let credit = try? NSRegularExpression(pattern: #"^\[[\d:.]+\]\s*[^:：\[\]]{1,12}\s*[:：]"#)

    private static func stripCredits(_ lrc: String) -> String {
        guard let credit else { return lrc }
        let kept = lrc.components(separatedBy: .newlines).filter { line in
            let range = NSRange(line.startIndex..., in: line)
            guard credit.firstMatch(in: line, range: range) != nil else { return true }
            return (LrcParser.parse(line).first?.time ?? 0) >= 30
        }
        let text = kept.joined(separator: "\n")
        return LrcParser.parse(text).contains { !$0.text.isEmpty } ? text : ""
    }

    private func fetch<T: Decodable>(_ url: URL?, as type: T.Type) async -> T? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 8
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
