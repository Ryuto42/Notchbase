import Foundation

struct LrclibClient {
    struct Response: Decodable {
        var id: Int?
        var trackName: String?
        var artistName: String?
        var duration: Double?
        var plainLyrics: String?
        var syncedLyrics: String?
        var instrumental: Bool?
    }

    private let session = URLSession(configuration: .ephemeral)
    private let userAgent = "Notchbase/0.1.0 (personal build)"

    func candidates(for playing: NowPlaying) async -> [LyricsCandidate] {
        async let exact = get(playing)
        async let searched = search(playing)
        let responses = [await exact].compactMap { $0 } + (await searched)
        return responses.map { response in
            LyricsCandidate(source: .lrclib,
                            title: response.trackName ?? "",
                            artists: [response.artistName ?? ""],
                            duration: response.duration,
                            synced: response.syncedLyrics,
                            plain: response.plainLyrics,
                            instrumental: response.instrumental ?? false)
        }
    }

    private func get(_ playing: NowPlaying) async -> Response? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: playing.artist),
            URLQueryItem(name: "track_name", value: playing.title),
            URLQueryItem(name: "album_name", value: playing.album),
            URLQueryItem(name: "duration", value: String(Int(playing.duration.rounded()))),
        ]
        return await fetch(components.url, as: Response.self)
    }

    private func search(_ playing: NowPlaying) async -> [Response] {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: playing.title),
            URLQueryItem(name: "artist_name", value: playing.artist),
        ]
        return await fetch(components.url, as: [Response].self) ?? []
    }

    private func fetch<T: Decodable>(_ url: URL?, as type: T.Type) async -> T? {
        guard let url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
