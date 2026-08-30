import AppKit
import Observation

@Observable
final class QueueArtworkLoader {
    private var cache: [URL: NSImage] = [:]
    @ObservationIgnored private var inFlight: Set<URL> = []

    func image(for url: URL?) -> NSImage? {
        guard let url else { return nil }
        return cache[url]
    }

    func prefetch(_ urls: [URL?]) {
        for case let url? in urls where cache[url] == nil && !inFlight.contains(url) {
            inFlight.insert(url)
            Task { [weak self] in
                let data = try? await URLSession.shared.data(from: url).0
                guard let self else { return }
                self.inFlight.remove(url)
                guard let data, let image = NSImage(data: data) else { return }
                self.cache[url] = image
            }
        }
    }
}
