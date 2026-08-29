import Foundation

/// Where the Spotify refresh token lives.
///
enum TokenStore {
    private static var url: URL { Paths.file("spotify-token") }

    static func write(_ value: String) {
        let data = Data(value.utf8)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func read() -> String? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
