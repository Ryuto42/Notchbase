import Foundation
import Observation
import AppKit
import ServiceManagement

@Observable
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    // MARK: - General

    var defaultTab: NotchTab = .media { didSet { store(defaultTab.rawValue, Key.defaultTab) } }
    var resumeSeconds: Double = 5 { didSet { store(resumeSeconds, Key.resumeSeconds) } }
    var hoverDelayMs: Int = 250 { didSet { store(hoverDelayMs, Key.hoverDelay) } }
    var nudgeMs: Int = 120 { didSet { store(nudgeMs, Key.nudge) } }
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

    var tabOrder: [NotchTab] = NotchTab.allCases { didSet { store(tabOrder.map(\.rawValue), Key.tabOrder) } }
    var hiddenTabs: Set<NotchTab> = [] { didSet { store(hiddenTabs.map(\.rawValue), Key.hiddenTabs) } }

    var visibleTabs: [NotchTab] {
        let ordered = tabOrder.isEmpty ? NotchTab.allCases : tabOrder
        guard !Debug.isDemo else { return ordered }
        let shown = ordered.filter { !hiddenTabs.contains($0) }
        return shown.isEmpty ? [ordered[0]] : shown
    }

    func isVisible(_ tab: NotchTab) -> Bool { visibleTabs.contains(tab) }

    // MARK: - Appearance

    var bottomFade: Bool = true { didSet { store(bottomFade, Key.bottomFade) } }
    var bottomFadeAmount: Double = 0.55 { didSet { store(bottomFadeAmount, Key.bottomFadeAmount) } }
    var clearGlassRail: Bool = true { didSet { store(clearGlassRail, Key.clearGlass) } }
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

    var sessionTarget: SessionTarget = .toolApp { didSet { store(sessionTarget.rawValue, Key.sessionTarget) } }

    var artworkAccent: Bool = true { didSet { store(artworkAccent, Key.artworkAccent) } }

    var agentHistoryDays: Int = 3 { didSet { store(agentHistoryDays, Key.agentDays) } }

    // MARK: - Lifecycle

    private static let registered: [String: Any] = [
        Key.defaultTab: NotchTab.media.rawValue,
        Key.tabOrder: NotchTab.allCases.map(\.rawValue),
        Key.hiddenTabs: [String](),
        Key.language: Language.system.rawValue,
        Key.resumeSeconds: 5.0,
        Key.hoverDelay: 250,
        Key.tabHoverDelay: 130,
        Key.nudge: 120,
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
        Key.artworkAccent: true,
        Key.shell: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh",
        Key.agentDays: 3,
        Key.sessionTarget: SessionTarget.toolApp.rawValue,
    ]

    private init() {
        defaults.register(defaults: Self.registered)
        load()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func load() {
        defaultTab = NotchTab(rawValue: defaults.string(forKey: Key.defaultTab) ?? "") ?? .media
        tabOrder = (defaults.stringArray(forKey: Key.tabOrder) ?? []).compactMap(NotchTab.init(rawValue:))
        hiddenTabs = Set((defaults.stringArray(forKey: Key.hiddenTabs) ?? []).compactMap(NotchTab.init(rawValue:)))
        language = Language(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system
        resumeSeconds = defaults.double(forKey: Key.resumeSeconds)
        hoverDelayMs = defaults.integer(forKey: Key.hoverDelay)
        tabHoverDelayMs = defaults.integer(forKey: Key.tabHoverDelay)
        nudgeMs = defaults.integer(forKey: Key.nudge)
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
        artworkAccent = defaults.bool(forKey: Key.artworkAccent)
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
        static let nudge = "nudgeMs"
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
        static let artworkAccent = "artworkAccent"
        static let shell = "terminalShell"
        static let agentDays = "agentHistoryDays"
        static let sessionTarget = "sessionTarget"
    }
}
