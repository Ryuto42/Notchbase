import AppKit
import Observation

@Observable
final class NotchViewModel {
    var state: NotchState = .closed
    var metrics: NotchMetrics
    var tab: NotchTab {
        get { Preferences.shared.isVisible(storedTab) ? storedTab : (Preferences.shared.visibleTabs.first ?? .media) }
        set { storedTab = newValue }
    }

    private var storedTab: NotchTab = Preferences.shared.defaultTab
    var isDropTargeted = false
    var isNudging = false

    @ObservationIgnored let tray = TrayStore()
    @ObservationIgnored let thumbnails = TrayThumbnailer()
    @ObservationIgnored let clipboard = ClipboardStore()
    @ObservationIgnored let media = MediaCoordinator()
    @ObservationIgnored let lyrics = LyricsController()
    @ObservationIgnored let battery = BatteryMonitor()
    @ObservationIgnored let agents = AgentMonitor()
    @ObservationIgnored let calendar = CalendarStore()

    var tabFrames: [NotchTab: CGRect] = [:]
    var hoveredTab: NotchTab?

    var onOpenSettings: (() -> Void)?
    var onOpenProject: ((AgentSession) -> Void)?
    var onClose: (() -> Void)?

    init(metrics: NotchMetrics) {
        self.metrics = metrics
    }

    var bodySize: CGSize {
        Layout.bodySize(for: state, metrics: metrics, tab: tab)
    }

    func sideWidth(for size: CGSize) -> CGFloat {
        max(0, (size.width - metrics.notchSize.width) / 2)
    }

    // MARK: - Activity

    enum Activity: Equatable, Hashable {
        case agents, media
    }

    var activity: Activity? {
        guard Preferences.shared.showActivityStrip else { return nil }
        let announced = agents.recentCompletion(within: Preferences.shared.announceSeconds) != nil
        let playing = media.current?.isPlaying == true

        switch Preferences.shared.activityPriority {
        case .agents:
            if announced { return .agents }
            return playing ? .media : nil
        case .media:
            if playing { return .media }
            return announced ? .agents : nil
        }
    }
}
