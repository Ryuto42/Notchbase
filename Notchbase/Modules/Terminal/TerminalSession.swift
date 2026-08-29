import AppKit
import Observation
import SwiftTerm

/// A single long-lived shell. The view is retained here rather than by SwiftUI so the
/// session survives the panel closing — long-running commands must not be killed.
@Observable
final class TerminalSession {
    static let shared = TerminalSession()

    @ObservationIgnored let view: LocalProcessTerminalView
    @ObservationIgnored private var started = false

    private init() {
        view = LocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 700, height: 300))
        view.nativeBackgroundColor = .black
        view.nativeForegroundColor = NSColor(white: 0.92, alpha: 1)
        view.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
    }

    func startIfNeeded() {
        guard !started else { return }
        started = true
        let shell = Preferences.shared.terminalShell
        var environment = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        environment.append("NOTCHBASE=1")
        view.startProcess(executable: shell, args: ["-l"], environment: environment)
    }

    /// Runs a command in the live session, e.g. `cd` into a tray item's folder.
    func send(_ text: String) {
        startIfNeeded()
        view.send(txt: text)
    }
}
