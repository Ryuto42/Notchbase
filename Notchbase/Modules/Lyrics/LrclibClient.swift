import Foundation

/// LRCLIB (https://lrclib.net) — keyless, community-maintained synced lyrics.
struct LrclibClient {
    struct Response: Decodable {
        var id: Int?
        var trackName: String?
        var artistName: String?
        var duration: Double?
        var plainLyrics: String?
        var syncedLyrics: String?
        var instrumental: Bool?

        var hasSynced: Bool { syncedLyrics?.isEmpty == false }
    }

    private let session = URLSession(configuration: .ephemeral)
    private let userAgent = "Notchbase/0.1.0 (personal build)"

    func lyrics(for playing: NowPlaying) async -> Response? {
        let exact = await get(playing)
        if exact?.hasSynced == true { return exact }

        let searched = await search(playing)
        if searched?.hasSynced == true { return searched }

        return exact ?? searched
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

    private func search(_ playing: NowPlaying) async -> Response? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: playing.title),
            URLQueryItem(name: "artist_name", value: playing.artist),
        ]
        guard let results = await fetch(components.url, as: [Response].self), !results.isEmpty else {
            return nil
        }
        // Prefer time-synced uploads, then whichever length is closest to what is playing —
        // the index is full of near-duplicates with slightly different runtimes.
        let synced = results.filter(\.hasSynced)
        let pool = synced.isEmpty ? results : synced
        guard playing.duration > 0 else { return pool.first }
        return pool.min {
            abs(($0.duration ?? 0) - playing.duration) < abs(($1.duration ?? 0) - playing.duration)
        }
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
