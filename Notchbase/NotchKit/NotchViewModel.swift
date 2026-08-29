import AppKit
import Observation

/// The hub every module hangs off. Owns the stores so their state survives panel open/close.
@Observable
final class NotchViewModel {
    var state: NotchState = .closed
    var metrics: NotchMetrics
    /// Always resolves to a tab the user still has switched on: hiding the tab you were
    /// last looking at must not leave its pane on screen.
    var tab: NotchTab {
        get { Preferences.shared.isVisible(storedTab) ? storedTab : (Preferences.shared.visibleTabs.first ?? .media) }
        set { storedTab = newValue }
    }

    private var storedTab: NotchTab = Preferences.shared.defaultTab
    var isDropTargeted = false

    @ObservationIgnored let tray = TrayStore()
    @ObservationIgnored let thumbnails = TrayThumbnailer()
    @ObservationIgnored let clipboard = ClipboardStore()
    @ObservationIgnored let media = MediaCoordinator()
    @ObservationIgnored let lyrics = LyricsController()
    @ObservationIgnored let battery = BatteryMonitor()
    @ObservationIgnored let agents = AgentMonitor()
    @ObservationIgnored let calendar = CalendarStore()

    /// Tab hit rects, in the root view's coordinate space, published by `TabRailView`.
    /// Hover switching is driven from the controller's pointer poll rather than SwiftUI's
    /// `.onHover`, which is unreliable in a non-key, non-activating panel.
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

    /// Width available on each side of the physical notch.
    func sideWidth(for size: CGSize) -> CGFloat {
        max(0, (size.width - metrics.notchSize.width) / 2)
    }

    // MARK: - Activity

    enum Activity: Equatable, Hashable {
        case agents, media
    }


    /// One activity at a time. A finished agent takes the strip for a few seconds and then
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
