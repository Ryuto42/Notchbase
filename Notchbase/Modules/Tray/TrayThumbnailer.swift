import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

@Observable
final class TrayThumbnailer {
    private var cache: [UUID: NSImage] = [:]
    private var icons: [UUID: NSImage] = [:]
    private var inFlight: Set<UUID> = []

    func image(for item: TrayItem, url: URL?) -> NSImage {
        if let cached = cache[item.id] { return cached }
        if let cached = icons[item.id] {
            if let url { request(item.id, url: url) }
            return cached
        }
        guard let url else {
            let icon = Self.typeIcon(for: item)
            icons[item.id] = icon
            return icon
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[item.id] = icon
        request(item.id, url: url)
        return icon
    }

    private static func typeIcon(for item: TrayItem) -> NSImage {
        if item.isDirectory { return NSWorkspace.shared.icon(for: .folder) }
        let ext = URL(fileURLWithPath: item.name).pathExtension
        return NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)
    }

    private func request(_ id: UUID, url: URL) {
        guard !inFlight.contains(id) else { return }
        inFlight.insert(id)
        let request = QLThumbnailGenerator.Request(fileAt: url,
                                                  size: CGSize(width: 96, height: 96),
                                                  scale: 2,
                                                  representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let representation else { return }
            let image = representation.nsImage
            Task { @MainActor [weak self] in
                self?.cache[id] = image
                self?.inFlight.remove(id)
            }
        }
    }
}
