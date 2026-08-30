import AppKit

enum AirDrop {
    static var isAvailable: Bool {
        NSSharingService(named: .sendViaAirDrop) != nil
    }

    static func send(_ urls: [URL]) {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate()
        service.perform(withItems: existing)
    }
}
