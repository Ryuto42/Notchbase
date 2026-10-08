import Foundation
import Security

enum TokenStore {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "\(Bundle.main.bundleIdentifier ?? "Notchbase").spotify",
        kSecAttrAccount as String: "refresh-token",
    ]

    // Earlier versions kept the token in a plain file.
    private static var legacyURL: URL { Paths.file("spotify-token") }

    @discardableResult
    static func write(_ value: String) -> Bool {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return status == errSecSuccess }
        var item = query
        item[kSecValueData as String] = data
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func read() -> String? {
        migrateLegacyFile()
        return load()
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
        try? FileManager.default.removeItem(at: legacyURL)
    }

    private static func load() -> String? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func migrateLegacyFile() {
        guard let data = try? Data(contentsOf: legacyURL) else { return }
        if let value = String(data: data, encoding: .utf8), !value.isEmpty, load() == nil {
            guard write(value) else { return }
        }
        try? FileManager.default.removeItem(at: legacyURL)
    }
}
