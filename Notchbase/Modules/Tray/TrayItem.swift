import Foundation

struct TrayItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var storedName: String?
    var bookmark: Data?
    var addedAt: Date
    var isCopy: Bool
    var isDirectory: Bool
    var byteSize: Int64
}
