import Foundation
import Observation
import AppKit
import ServiceManagement

/// Every user-facing knob, backed by `UserDefaults`.
///
/// Values are read all over the app — `Layout` and `Motion` consult them directly — so the
/// panel reshapes itself as soon as something changes here.
@Observable
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    // MARK: - General

    /// Tab shown when the panel opens fresh.
    var defaultTab: NotchTab = .media { didSet { store(defaultTab.rawValue, Key.defaultTab) } }
    /// Reopening within this many seconds keeps the tab you were last on. 0 disables it.
    var resumeSeconds: Double = 5 { didSet { store(resumeSeconds, Key.resumeSeconds) } }
    /// How long the pointer must rest on the notch before the panel opens.
    var hoverDelayMs: Int = 250 { didSet { store(hoverDelayMs, Key.hoverDelay) } }
    /// Dwell before hovering a tab switches to it.
    var tabHoverDelayMs: Int = 130 { didSet { store(tabHoverDelayMs, Key.tabHoverDelay) } }

    var launchAtLogin: Bool = false {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = oldValue
            }
        }
    }

    // MARK: - Tabs

    enum Language: String, CaseIterable, Identifiable {
        case system, english, japanese
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: "System"
            case .english: "English"
            case .japanese: "日本語"
            }
        }
        var code: String? {
            switch self {
            case .system: nil
            case .english: "en"
            case .japanese: "ja"
            }
        }
    }

    var language: Language = .system { didSet { store(language.rawValue, Key.language) } }

    /// Order the tabs appear in, including hidden ones so unhiding restores the position.
    var tabOrder: [NotchTab] = NotchTab.allCases { didSet { store(tabOrder.map(\.rawValue), Key.tabOrder) } }
    var hiddenTabs: Set<NotchTab> = [] { didSet { store(hiddenTabs.map(\.rawValue), Key.hiddenTabs) } }

    /// Tabs actually shown, in order. Never empty — hiding everything would strand the panel.
    var visibleTabs: [NotchTab] {
        let ordered = tabOrder.isEmpty ? NotchTab.allCases : tabOrder
        guard !Debug.isDemo else { return ordered }
        let shown = ordered.filter { !hiddenTabs.contains($0) }
        return shown.isEmpty ? [ordered[0]] : shown
    }

    func isVisible(_ tab: NotchTab) -> Bool { visibleTabs.contains(tab) }

    // MARK: - Appearance

    /// Dissolve the lower edge of the panel into the desktop.
    var bottomFade: Bool = true { didSet { store(bottomFade, Key.bottomFade) } }
    /// How much of the panel the fade covers, 0...1.
    var bottomFadeAmount: Double = 0.55 { didSet { store(bottomFadeAmount, Key.bottomFadeAmount) } }
    /// Clear glass for the tab rail instead of the more solid regular glass.
    var clearGlassRail: Bool = true { didSet { store(clearGlassRail, Key.clearGlass) } }
    /// Opacity of the tab switcher's glass and button fills. The glyphs stay legible.
    var tabRailOpacity: Double = 0.82 { didSet { store(tabRailOpacity, Key.tabRailOpacity) } }
    var showTabLabels: Bool = true { didSet { store(showTabLabels, Key.tabLabels) } }

    enum MotionStyle: String, CaseIterable, Identifiable {
        case snappy, balanced, calm
        var id: String { rawValue }
        var title: String {
            switch self {
            case .snappy: "Snappy"
            case .balanced: "Balanced"
            case .calm: "Calm"
            }
        }
        /// Multiplies every spring's response — higher is slower.
        var scale: Double {
            switch self {
            case .snappy: 0.72
            case .balanced: 1
            case .calm: 1.45
            }
        }
    }

    var motionStyle: MotionStyle = .balanced { didSet { store(motionStyle.rawValue, Key.motion) } }

    // MARK: - Activity strip

    var showActivityStrip: Bool = true { didSet { store(showActivityStrip, Key.activityStrip) } }

    enum ActivityPriority: String, CaseIterable, Identifiable {
        case agents, media
        var id: String { rawValue }
        var title: String {
            switch self {
            case .agents: "Agent completions"
            case .media: "Now playing"
            }
        }
    }

    var activityPriority: ActivityPriority = .agents { didSet { store(activityPriority.rawValue, Key.activityPriority) } }
    /// How long a finished agent keeps the strip.
    var announceSeconds: Double = 8 { didSet { store(announceSeconds, Key.announce) } }

    // MARK: - Modules

    var copyDroppedFiles: Bool = true { didSet { store(copyDroppedFiles, Key.copyFiles) } }
    var showAirDropZone: Bool = true { didSet { store(showAirDropZone, Key.airDrop) } }
    var clipboardEnabled: Bool = true { didSet { store(clipboardEnabled, Key.clipEnabled) } }
    var clipboardLimit: Int = 200 { didSet { store(clipboardLimit, Key.clipLimit) } }
    var lyricsEnabled: Bool = true { didSet { store(lyricsEnabled, Key.lyricsEnabled) } }
    var lyricsOffset: Double = 0 { didSet { store(lyricsOffset, Key.lyricsOffset) } }
    var queueLimit: Int = 8 { didSet { store(queueLimit, Key.queueLimit) } }
    var terminalShell: String = "/bin/zsh" { didSet { store(terminalShell, Key.shell) } }
    enum SessionTarget: String, CaseIterable, Identifiable {
        case toolApp, terminalApp, builtIn, cursor, vscode

        var id: String { rawValue }

        var title: String {
            switch self {
            case .toolApp: "Claude / Codex app"
            case .terminalApp: "Terminal app"
            case .builtIn: "Notchbase terminal"
            case .cursor: "Cursor"
            case .vscode: "Visual Studio Code"
            }
        }

        var bundleID: String? {
            switch self {
            case .cursor: "com.todesktop.230313mzl4w4u92"
            case .vscode: "com.microsoft.VSCode"
            case .toolApp, .terminalApp, .builtIn: nil
            }
        }

        var isAvailable: Bool {
            guard let bundleID else { return true }
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }

        static var installed: [SessionTarget] { allCases.filter(\.isAvailable) }
    }

    /// Where clicking an agent session resumes it.
    var sessionTarget: SessionTarget = .toolApp { didSet { store(sessionTarget.rawValue, Key.sessionTarget) } }

    /// Days of agent transcripts to keep in the list.
    var agentHistoryDays: Int = 3 { didSet { store(agentHistoryDays, Key.agentDays) } }

    // MARK: - Lifecycle

    /// The one place a default lives. `load()` and `resetToDefaults()` both read from it, so
    /// adding a setting means touching this table and nothing else.
    private static let registered: [String: Any] = [
        Key.defaultTab: NotchTab.media.rawValue,
        Key.tabOrder: NotchTab.allCases.map(\.rawValue),
        Key.hiddenTabs: [String](),
        Key.language: Language.system.rawValue,
        Key.resumeSeconds: 5.0,
        Key.hoverDelay: 250,
        Key.tabHoverDelay: 130,
        Key.bottomFade: true,
        Key.bottomFadeAmount: 0.55,
        Key.tabRailOpacity: 0.82,
        Key.clearGlass: true,
        Key.tabLabels: true,
        Key.motion: MotionStyle.balanced.rawValue,
        Key.activityStrip: true,
        Key.activityPriority: ActivityPriority.agents.rawValue,
        Key.announce: 8.0,
        Key.copyFiles: true,
        Key.airDrop: true,
        Key.clipEnabled: true,
        Key.clipLimit: 200,
        Key.lyricsEnabled: true,
        Key.lyricsOffset: 0.0,
        Key.queueLimit: 8,
        Key.shell: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh",
        Key.agentDays: 3,
        Key.sessionTarget: SessionTarget.toolApp.rawValue,
    ]

    private init() {
        defaults.register(defaults: Self.registered)
        load()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Pulls every setting out of `UserDefaults`. Each `didSet` writes the same value straight
    /// back, which is harmless and keeps the assignment list to one per setting.
    private func load() {
        defaultTab = NotchTab(rawValue: defaults.string(forKey: Key.defaultTab) ?? "") ?? .media
        tabOrder = (defaults.stringArray(forKey: Key.tabOrder) ?? []).compactMap(NotchTab.init(rawValue:))
        hiddenTabs = Set((defaults.stringArray(forKey: Key.hiddenTabs) ?? []).compactMap(NotchTab.init(rawValue:)))
        language = Language(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system
        resumeSeconds = defaults.double(forKey: Key.resumeSeconds)
        hoverDelayMs = defaults.integer(forKey: Key.hoverDelay)
        tabHoverDelayMs = defaults.integer(forKey: Key.tabHoverDelay)
        bottomFade = defaults.bool(forKey: Key.bottomFade)
        bottomFadeAmount = defaults.double(forKey: Key.bottomFadeAmount)
        clearGlassRail = defaults.bool(forKey: Key.clearGlass)
        tabRailOpacity = defaults.double(forKey: Key.tabRailOpacity)
        showTabLabels = defaults.bool(forKey: Key.tabLabels)
        motionStyle = MotionStyle(rawValue: defaults.string(forKey: Key.motion) ?? "") ?? .balanced
        showActivityStrip = defaults.bool(forKey: Key.activityStrip)
        activityPriority = ActivityPriority(rawValue: defaults.string(forKey: Key.activityPriority) ?? "") ?? .agents
        announceSeconds = defaults.double(forKey: Key.announce)
        copyDroppedFiles = defaults.bool(forKey: Key.copyFiles)
        showAirDropZone = defaults.bool(forKey: Key.airDrop)
        clipboardEnabled = defaults.bool(forKey: Key.clipEnabled)
        clipboardLimit = defaults.integer(forKey: Key.clipLimit)
        lyricsEnabled = defaults.bool(forKey: Key.lyricsEnabled)
        lyricsOffset = defaults.double(forKey: Key.lyricsOffset)
        queueLimit = defaults.integer(forKey: Key.queueLimit)
        terminalShell = defaults.string(forKey: Key.shell) ?? "/bin/zsh"
        agentHistoryDays = defaults.integer(forKey: Key.agentDays)
        sessionTarget = SessionTarget(rawValue: defaults.string(forKey: Key.sessionTarget) ?? "") ?? .toolApp
    }

    func resetToDefaults() {
        for key in Self.registered.keys { defaults.removeObject(forKey: key) }
        load()
    }

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private enum Key {
        static let defaultTab = "defaultTab"
        static let resumeSeconds = "resumeSeconds"
        static let hoverDelay = "hoverDelayMs"
        static let tabHoverDelay = "tabHoverDelayMs"
        static let tabOrder = "tabOrder"
        static let hiddenTabs = "hiddenTabs"
        static let language = "language"
        static let bottomFade = "bottomFade"
        static let bottomFadeAmount = "bottomFadeAmount"
        static let clearGlass = "clearGlassRail"
        static let tabRailOpacity = "tabRailOpacity"
        static let tabLabels = "showTabLabels"
        static let motion = "motionStyle"
        static let activityStrip = "showActivityStrip"
        static let activityPriority = "activityPriority"
        static let announce = "announceSeconds"
        static let copyFiles = "copyDroppedFiles"
        static let airDrop = "showAirDropZone"
        static let clipEnabled = "clipboardEnabled"
        static let clipLimit = "clipboardLimit"
        static let lyricsEnabled = "lyricsEnabled"
        static let lyricsOffset = "lyricsOffset"
        static let queueLimit = "queueLimit"
        static let shell = "terminalShell"
        static let agentDays = "agentHistoryDays"
        static let sessionTarget = "sessionTarget"

    }
}
