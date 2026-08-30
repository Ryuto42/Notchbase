import AppKit
import Observation
import Sparkle

@Observable
@MainActor
final class UpdateController {
    static let shared = UpdateController()

    @ObservationIgnored private let driverDelegate = UserDriverDelegate()
    @ObservationIgnored private let updaterController: SPUStandardUpdaterController
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private var lastCheckObservation: NSKeyValueObservation?

    private(set) var canCheck = true
    private(set) var lastCheck: Date?

    private var updater: SPUUpdater { updaterController.updater }

    var automaticallyChecks: Bool {
        get {
            _ = touch
            return updater.automaticallyChecksForUpdates
        }
        set {
            updater.automaticallyChecksForUpdates = newValue
            touch += 1
        }
    }

    var automaticallyDownloads: Bool {
        get {
            _ = touch
            return updater.automaticallyDownloadsUpdates
        }
        set {
            updater.automaticallyDownloadsUpdates = newValue
            touch += 1
        }
    }

    private var touch = 0

    var feedURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    }

    private init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: false,
                                                         updaterDelegate: nil,
                                                         userDriverDelegate: driverDelegate)
    }

    func start() {
        guard !feedURL.isEmpty else { return }
        do {
            try updater.start()
        } catch {
            NSLog("Notchbase: updater failed to start — \(error.localizedDescription)")
            return
        }
        updater.updateCheckInterval = 60 * 60 * 6
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
        }
        lastCheckObservation = updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.lastCheck = updater.lastUpdateCheckDate }
        }
    }

    func checkNow() {
        updater.checkForUpdates()
    }
}

private final class UserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        guard handleShowingUpdate else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func standardUserDriverWillFinishUpdateSession() {
        NSApp.setActivationPolicy(.accessory)
    }
}
