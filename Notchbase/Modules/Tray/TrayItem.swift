import Foundation

struct TrayItem: Identifiable, Codable, Hashable {
    let id: UUID
    /// Display name.
    var name: String
    /// File name inside the tray directory when `isCopy`, otherwise a bookmark is used.
    var storedName: String?
    /// Original location, kept for "Reveal in Finder" and for reference-mode items.
    var bookmark: Data?
    var addedAt: Date
    var isCopy: Bool
    var isDirectory: Bool
    var byteSize: Int64
}
