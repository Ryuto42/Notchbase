import AppKit

enum AirDrop {
    static var isAvailable: Bool {
        NSSharingService(named: .sendViaAirDrop) != nil
    }

    /// Opens the system AirDrop sheet for the given files.
    static func send(_ urls: [URL]) {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        // The panel is non-activating, so without this the AirDrop window opens behind.
        NSApp.activate()
        service.perform(withItems: existing)
    }
}
