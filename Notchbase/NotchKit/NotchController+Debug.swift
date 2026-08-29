import AppKit
import SwiftUI

/// Hooks that only ever run when a `NOTCHBASE_*` variable is set — see `Debug`.
extension NotchController {
    /// `NOTCHBASE_FORCE_TAB=media NOTCHBASE_FORCE_STATE=expanded` pins the panel open so the
    /// layout can be inspected (and screenshotted) without chasing it with the pointer.
    var forcedState: NotchState? {
        switch Debug.value("FORCE_STATE") {
        case "expanded": .expanded
        case "activity": .activity
        default: nil
        }
    }

    var isDebugPinned: Bool { forcedState != nil }

    /// `NOTCHBASE_SNAPSHOT=/tmp/shot.png` renders the expanded panel offscreen and quits.
    /// Screen recording permission is not always available, and this is a faster loop for
    /// checking layout than asking someone to take a screenshot.
    func captureSnapshot(to path: String) {
        Debug.log("snapshot: activity=\(String(describing: model.activity)) completion=\(String(describing: model.agents.recentCompletion()?.title)) priority=\(Preferences.shared.activityPriority.rawValue) upNext=\(model.media.upNext.count) tab=\(model.tab) current=\(model.media.current?.title ?? "-")")
        model.state = forcedState ?? .expanded
        let content = NotchRootView(model: model)
            .frame(width: Layout.containerSize.width, height: Layout.containerSize.height)
            .background(LinearGradient(colors: [Color(red: 0.16, green: 0.10, blue: 0.28),
                                                Color(red: 0.48, green: 0.24, blue: 0.16)],
                                       startPoint: .top, endPoint: .bottom))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        if let image = renderer.nsImage, let data = image.pngData {
            try? data.write(to: URL(fileURLWithPath: path))
        }
        NSApp.terminate(nil)
    }

    func applyDebugOverride() {
        if Debug.flag("DEMO") {
            DemoContent.install(into: model)
        }

        if let raw = Debug.value("FORCE_TAB"), let tab = NotchTab(rawValue: raw) {
            model.tab = tab
        }
        if Debug.flag("TEST_ACTIVATE") {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard let self else { return }
                self.model.media.activatePlayer()
                let failure = AppleScriptRunner.shared.lastFailure
                Debug.log("activate attempted, adapter=\(String(describing: self.model.media.current?.source.rawValue)) failure=\(failure?.code ?? 0) \(failure?.message ?? "-")")
            }
        }
        if Debug.flag("CONNECT_SPOTIFY") {
            Task {
                try? await Task.sleep(for: .seconds(1))
                SpotifyAuth.shared.connect()
            }
        }
        if Debug.flag("OPEN_SETTINGS") {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                self?.openSettings()
            }
        }
        if let path = Debug.value("SNAPSHOT") {
            Task { [weak self] in
                // Give artwork and lyrics a moment to land before rendering.
                try? await Task.sleep(for: .seconds(7))
                self?.captureSnapshot(to: path)
            }
        }
        guard let forcedState else { return }
        apply(forcedState)
        panel?.ignoresMouseEvents = false
    }
}
