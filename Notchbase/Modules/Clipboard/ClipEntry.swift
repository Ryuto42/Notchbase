import Foundation

enum ClipKind: String, Codable {
    case text, image, fileURL
}

struct ClipEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: ClipKind
    /// Text payload, or the path string for `fileURL`.
    var text: String?
    /// PNG file name inside the Clipboard directory.
    var imageName: String?
    var createdAt: Date
    var pinned: Bool

    var preview: String {
        switch kind {
        case .text: (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        case .fileURL: URL(fileURLWithPath: text ?? "").lastPathComponent
        case .image: "Image"
        }
    }
}
