import Foundation

/// The only thing the Web API is used for: the play queue, which the desktop app's
/// AppleScript dictionary does not expose at all.
struct SpotifyWebClient {
    private struct QueueResponse: Decodable {
        struct Artist: Decodable { var name: String }
        struct Image: Decodable { var url: String; var width: Int? }
        struct Album: Decodable { var images: [Image]? }
        struct Item: Decodable {
            var name: String?
            var uri: String?
            var artists: [Artist]?
            var album: Album?
        }
        var queue: [Item]?
    }

    private struct PlayerResponse: Decodable {
        struct Context: Decodable { var uri: String? }
        var context: Context?
    }

    /// The album or playlist playback is currently running through.
    func playbackContext() async -> String? {
        guard let token = await SpotifyAuth.shared.validAccessToken() else { return nil }
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(PlayerResponse.self, from: data) else {
            return nil
        }
        return decoded.context?.uri
    }

    func upNext(limit: Int = Preferences.shared.queueLimit) async -> [QueueEntry] {
        guard let token = await SpotifyAuth.shared.validAccessToken() else { return [] }

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/queue")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return [] }
        guard http.statusCode == 200 else {
            Debug.log("queue HTTP \(http.statusCode)")
            return []
        }
        let decoded: QueueResponse
        do {
            decoded = try JSONDecoder().decode(QueueResponse.self, from: data)
        } catch {
            Debug.log("queue decode failed: \(error)")
            return []
        }
        Debug.log("queue decoded \((decoded.queue ?? []).count) items")

        let context = await playbackContext()
        return (decoded.queue ?? []).prefix(limit).enumerated().map { offset, item in
            // Smallest image that is still sharp at the row size.
            let art = item.album?.images?
                .filter { ($0.width ?? 0) >= 64 }
                .min { ($0.width ?? 0) < ($1.width ?? 0) }
                ?? item.album?.images?.first
            return QueueEntry(id: offset,
                              title: item.name ?? "Unknown",
                              artist: (item.artists ?? []).map(\.name).joined(separator: ", "),
                              artworkURL: art.flatMap { URL(string: $0.url) },
                              handle: item.uri,
                              contextURI: context)
        }
    }
}
