import AppKit
import SwiftUI

final class NotchController {
    var panel: NotchPanel?
    private var container: PassthroughView?
    let model: NotchViewModel
    private var metrics: NotchMetrics
    private let pointer = PointerMonitor()
    private let settings = SettingsWindowController()

    private var transitionTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var idleTimer: Timer?
    private var pendingState: NotchState?
    private var lastPointer = NSEvent.mouseLocation
    private var isFileDragging = false
    private var hoverTimer: Timer?
    private var collapsedAt = Date.distantPast

    private var pollCount = 0
    private var tabCandidate: NotchTab?
    private var tabCandidateSince = Date.distantFuture

    init() {
        let screen = NotchMetrics.preferredScreen()
        metrics = screen.map(NotchMetrics.measure)
            ?? NotchMetrics(screenFrame: .zero, notchSize: Layout.pseudoNotchSize, notchCenterX: 0, hasRealNotch: false)
        model = NotchViewModel(metrics: metrics)
    }

    // MARK: - Lifecycle

    func start() {
        model.onOpenSettings = { [weak self] in self?.settings.show() }
        model.onClose = { [weak self] in self?.collapse() }
        model.onOpenProject = { [weak self] session in self?.openProject(session) }

        build()
        Debug.log("started metrics=\(metrics)")

        Debug.log("clipboard")
        model.clipboard.start()
        Debug.log("battery")
        model.battery.start()
        model.agents.start()
        model.calendar.start()
        Debug.log("media")
        model.media.onTrackChange = { [weak self] playing in
            self?.model.lyrics.update(for: playing)
        }
        model.media.start()
        Debug.log("pointer")

        pointer.onFileDragMove = { [weak self] in self?.handleFileDrag($0) }
        pointer.onFileDragEnd = { [weak self] in self?.handleFileDragEnd() }
        pointer.onClick = { [weak self] in self?.handleClick($0) }
        pointer.start()

        let hover = Timer(timeInterval: 0.03, repeats: true) { _ in
            MainActor.assumeIsolated { self.pollPointer() }
        }
        RunLoop.main.add(hover, forMode: .common)
        hoverTimer = hover
        Debug.log("hover timer scheduled isValid=\(hover.isValid)")

        let idle = Timer(timeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { self.refreshIdleState() }
        }
        RunLoop.main.add(idle, forMode: .common)
        idleTimer = idle

        Debug.log("idle timer scheduled")
        applyDebugOverride()
        Debug.log("start complete")

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.rebuild() }
        }
    }

    func stop() {
        pointer.stop()
        hoverTimer?.invalidate()
        idleTimer?.invalidate()
        transitionTask?.cancel()
        model.clipboard.stop()
        model.battery.stop()
        model.agents.stop()
        model.calendar.stop()
        model.media.stop()
        panel?.orderOut(nil)
    }

    func rebuild() {
        panel?.orderOut(nil)
        panel = nil
        container = nil
        guard let screen = NotchMetrics.preferredScreen() else { return }
        metrics = NotchMetrics.measure(screen)
        model.metrics = metrics
        build()
    }

    func openSettings() {
        settings.show()
    }

    private func openProject(_ session: AgentSession) {
        guard let directory = session.directory else { return }
        let command = "cd \(shellQuoted(directory)) && \(session.tool.command)"

        let target = Preferences.shared.sessionTarget
        switch target.isAvailable ? target : .terminalApp {
        case .toolApp:
            if let link = session.tool.deepLink(for: directory) {
                NSWorkspace.shared.open(link)
            }
        case .cursor, .vscode:
            guard let bundleID = target.bundleID,
                  let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            else { return }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([URL(fileURLWithPath: directory)],
                                    withApplicationAt: app,
                                    configuration: configuration)
        case .terminalApp:
            let script = "tell application \"Terminal\"\nactivate\ndo script \"\(appleScriptQuoted(command))\"\nend tell"
            AppleScriptRunner.shared.execute(script)
        case .builtIn:
            model.tab = .terminal
            apply(.expanded)
            panel?.keyEligible = true
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate()
            TerminalSession.shared.send(command + "\n")
        }
    }

    private func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptQuoted(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func build() {
        let frame = CGRect(
            x: metrics.notchCenterX - Layout.containerSize.width / 2,
            y: metrics.screenFrame.maxY - Layout.containerSize.height,
            width: Layout.containerSize.width,
            height: Layout.containerSize.height
        )

        let panel = NotchPanel(contentRect: frame)
        let container = PassthroughView(frame: CGRect(origin: .zero, size: Layout.containerSize))
        container.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: NotchRootView(model: model))
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)

        panel.contentView = container
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()

        self.panel = panel
        self.container = container
        apply(idleState)
    }

    // MARK: - State

    func apply(_ state: NotchState) {
        if let forcedState, state != forcedState { return }
        guard model.state != state else {
            syncHitArea()
            return
        }
        cancelTransition()
        hideTask?.cancel()
        if state == .closed {
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Motion.stateDuration))
                guard !Task.isCancelled, let self, self.model.state == .closed else { return }
                self.model.isVisible = false
            }
        } else if !model.isVisible {
            model.isVisible = true
            DispatchQueue.main.async { [weak self] in self?.apply(state) }
            return
        }
        Debug.log("\(model.state) -> \(state) tab=\(model.tab) key=\(panel?.isKeyWindow == true) ignoreMouse=\(panel?.ignoresMouseEvents == true)")
        if state == .expanded, model.state != .expanded, !isDebugPinned {
            if !isFileDragging, Date().timeIntervalSince(collapsedAt) > Preferences.shared.resumeSeconds {
                let wanted = Preferences.shared.defaultTab
                model.tab = Preferences.shared.isVisible(wanted)
                    ? wanted
                    : Preferences.shared.visibleTabs[0]
            }
        } else if state != .expanded, model.state == .expanded {
            collapsedAt = Date()
        }
        model.state = state
        if state != .expanded {
            model.hoveredTab = nil
            tabCandidate = nil
            tabCandidateSince = .distantFuture
        }
        panel?.keyEligible = state.acceptsKeyInput
        if !state.acceptsKeyInput, panel?.isKeyWindow == true {
            panel?.resignKey()
        }
        syncHitArea()
        updateMouseTransparency()
    }

    private func updateMouseTransparency() {
        guard let panel else { return }
        if isFileDragging {
            panel.ignoresMouseEvents = false
            return
        }
        let body = bodyRectInScreen(for: model.state).insetBy(dx: -2, dy: -2)
        panel.ignoresMouseEvents = !body.contains(lastPointer)
    }

    private func syncHitArea() {
        let target = bodyRectInPanel(for: model.state)
        if let current = container?.activeRect, target.width * target.height > current.width * current.height {
            container?.activeRect = target
        } else {
            let state = model.state
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(240))
                guard let self, self.model.state == state else { return }
                self.container?.activeRect = self.bodyRectInPanel(for: state)
            }
        }
    }

    private var isHoldingOpen: Bool {
        model.calendar.draft != nil
    }

    private var idleState: NotchState {
        model.activity != nil ? .activity : .closed
    }

    private func refreshIdleState() {
        guard model.state == .closed || model.state == .activity else { return }
        apply(idleState)
    }

    func toggleExpanded() {
        if model.state == .expanded {
            collapse()
        } else {
            expand()
        }
    }

    private func expand() {
        apply(.expanded)
    }

    private func collapse() {
        apply(idleState)
    }

    private func schedule(_ state: NotchState, after delay: Duration) {
        guard pendingState != state else { return }
        transitionTask?.cancel()
        pendingState = state
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.pendingState = nil
            self.apply(state)
        }
    }

    private func cancelTransition() {
        transitionTask?.cancel()
        transitionTask = nil
        pendingState = nil
    }

    // MARK: - Geometry

    private func bodyRectInScreen(for state: NotchState) -> CGRect {
        let body = Layout.interactiveSize(for: state, metrics: metrics, tab: model.tab)
        let width = body.width + 2 * Layout.topRadius(for: state)
        return CGRect(x: metrics.notchCenterX - width / 2,
                      y: metrics.screenFrame.maxY - body.height,
                      width: width,
                      height: body.height)
    }

    private func bodyRectInPanel(for state: NotchState) -> CGRect {
        let body = Layout.interactiveSize(for: state, metrics: metrics, tab: model.tab)
        let width = body.width + 2 * Layout.topRadius(for: state)
        return CGRect(x: (Layout.containerSize.width - width) / 2,
                      y: Layout.containerSize.height - body.height,
                      width: width,
                      height: body.height)
    }

    private func isInHoverZone(_ point: CGPoint) -> Bool {
        let zone = hoverZone
        return point.x >= zone.minX && point.x <= zone.maxX
            && point.y >= zone.minY && point.y <= metrics.screenFrame.maxY
    }

    private var hoverZone: CGRect {
        let collapsed: NotchState = model.state == .activity ? .activity : .closed
        let body = Layout.bodySize(for: collapsed, metrics: metrics, tab: model.tab)
        return CGRect(x: metrics.notchCenterX - body.width / 2 - Layout.hoverSideSlop,
                      y: metrics.screenFrame.maxY - body.height - Layout.hoverSlop,
                      width: body.width + 2 * Layout.hoverSideSlop,
                      height: body.height + Layout.hoverSlop)
    }

    // MARK: - Pointer handling

    private func pollPointer() {
        guard !isDebugPinned else { return }
        let point = NSEvent.mouseLocation
        if Debug.isLogging {
            pollCount += 1
            if pollCount % 40 == 0 {
                Debug.log("poll #\(pollCount) pointer=\(point) state=\(model.state) zone=\(hoverZone) inZone=\(isInHoverZone(point))")
            }
        }
        lastPointer = point
        updateMouseTransparency()

        if isFileDragging {
            evaluateFileDrag(point)
            return
        }

        switch model.state {
        case .expanded:
            updateHoveredTab(point)
            if bodyRectInScreen(for: .expanded).insetBy(dx: -10, dy: -10).contains(point)
                || isInHoverZone(point) || isHoldingOpen {
                cancelTransition()
            } else {
                schedule(idleState, after: .milliseconds(200))
            }
        case .closed, .activity:
            if isInHoverZone(point) {
                schedule(.expanded, after: .milliseconds(max(0, Preferences.shared.hoverDelayMs)))
            } else {
                cancelTransition()
            }
        }
    }

    private func updateHoveredTab(_ point: CGPoint) {
        guard let panel else { return }
        let origin = CGPoint(x: panel.frame.minX, y: panel.frame.maxY)

        let hit = model.tabFrames.first { tab, local in
            guard Preferences.shared.isVisible(tab) else { return false }
            return CGRect(x: origin.x + local.minX,
                   y: origin.y - local.maxY,
                   width: local.width,
                   height: local.height).contains(point)
        }?.key

        model.hoveredTab = hit
        if Debug.isLogging, pollCount % 20 == 0 {
            let rects = model.tabFrames.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " ")
            Debug.log("tabs hit=\(hit?.rawValue ?? "-") origin=\(origin) frames[\(model.tabFrames.count)] \(rects)")
        }

        guard let hit, hit != model.tab else {
            tabCandidate = nil
            tabCandidateSince = .distantFuture
            return
        }
        if tabCandidate != hit {
            tabCandidate = hit
            tabCandidateSince = Date()
            return
        }
        if Date().timeIntervalSince(tabCandidateSince) >= Double(Preferences.shared.tabHoverDelayMs) / 1000 {
            Debug.log("switch tab -> \(hit.rawValue)")
            model.tab = hit
            tabCandidate = nil
            tabCandidateSince = .distantFuture
        }
    }

    private var dropTriggerZone: CGRect {
        let notch = metrics.notchSize
        let width = notch.width + 150
        let height: CGFloat = 64
        return CGRect(x: metrics.notchCenterX - width / 2,
                      y: metrics.screenFrame.maxY - height,
                      width: width,
                      height: height)
    }

    private func handleFileDrag(_ point: CGPoint) {
        lastPointer = point
        isFileDragging = true
        updateMouseTransparency()
        evaluateFileDrag(point)
    }

    private func evaluateFileDrag(_ point: CGPoint) {
        let overPanel = model.state == .expanded
            && bodyRectInScreen(for: .expanded).insetBy(dx: -10, dy: -10).contains(point)

        if dropTriggerZone.contains(point) || overPanel {
            cancelTransition()
            guard Preferences.shared.isVisible(.tray) else { return }
            apply(.expanded)
            if model.tab != .tray { model.tab = .tray }
        } else if model.state == .expanded {
            schedule(idleState, after: .milliseconds(180))
        }
    }

    private func handleFileDragEnd() {
        isFileDragging = false
        updateMouseTransparency()
        guard model.state == .expanded else { return }
        schedule(idleState, after: .milliseconds(900))
    }

    private func handleClick(_ point: CGPoint) {
        guard model.state != .closed else { return }
        if bodyRectInScreen(for: model.state).contains(point) {
            if model.state == .expanded,
               model.tab == .terminal || model.tab == .clipboard || model.tab == .calendar {
                panel?.keyEligible = true
                panel?.makeKeyAndOrderFront(nil)
                NSApp.activate()
            }
        } else if model.state == .expanded {
            apply(idleState)
        }
    }
}
