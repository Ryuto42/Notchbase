import AppKit
import Observation

@Observable
final class TrayStore {
    private(set) var items: [TrayItem] = []

    func applyDemo(_ demo: [TrayItem]) { items = demo }

    private let indexURL = Paths.file("tray.json")
    private let filesDir = Paths.directory("Tray")

    init() {
        items = JSONStore.load([TrayItem].self, from: indexURL) ?? []
        prune()
    }

    // MARK: - Mutation

    func add(_ urls: [URL]) {
        let copy = Preferences.shared.copyDroppedFiles
        for url in urls {
            guard let item = makeItem(from: url, copy: copy) else { continue }
            items.insert(item, at: 0)
        }
        persist()
    }

    func remove(_ item: TrayItem) {
        if item.isCopy, let stored = item.storedName {
            try? FileManager.default.removeItem(at: filesDir.appendingPathComponent(stored))
        }
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        for item in items where item.isCopy {
            guard let stored = item.storedName else { continue }
            try? FileManager.default.removeItem(at: filesDir.appendingPathComponent(stored))
        }
        items.removeAll()
        persist()
    }

    // MARK: - Access

    func url(for item: TrayItem) -> URL? {
        if item.isCopy, let stored = item.storedName {
            let url = filesDir.appendingPathComponent(stored)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        guard let bookmark = item.bookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark,
                                 options: [.withSecurityScope],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return nil }
        return url
    }

    func reveal(_ item: TrayItem) {
        guard let url = url(for: item) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func open(_ item: TrayItem) {
        guard let url = url(for: item) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Internals

    private func makeItem(from url: URL, copy: Bool) -> TrayItem? {
        let fm = FileManager.default
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        let isDirectory = values?.isDirectory ?? false
        let size = Int64(values?.fileSize ?? 0)

        if copy {
            let stored = "\(UUID().uuidString)-\(url.lastPathComponent)"
            let destination = filesDir.appendingPathComponent(stored)
            do {
                try fm.copyItem(at: url, to: destination)
            } catch {
                return nil
            }
            return TrayItem(id: UUID(), name: url.lastPathComponent, storedName: stored,
                            bookmark: try? url.bookmarkData(options: .withSecurityScope),
                            addedAt: Date(), isCopy: true,
                            isDirectory: isDirectory, byteSize: size)
        }

        guard let bookmark = try? url.bookmarkData(options: .withSecurityScope) else { return nil }
        return TrayItem(id: UUID(), name: url.lastPathComponent, storedName: nil,
                        bookmark: bookmark, addedAt: Date(), isCopy: false,
                        isDirectory: isDirectory, byteSize: size)
    }

    private func prune() {
        let before = items.count
        items.removeAll { url(for: $0) == nil }
        if items.count != before { persist() }
    }

    private func persist() {
        JSONStore.save(items, to: indexURL)
    }
}
