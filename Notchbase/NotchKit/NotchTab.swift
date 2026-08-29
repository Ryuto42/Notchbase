enum NotchTab: String, CaseIterable, Identifiable, Codable {
    case tray, clipboard, media, terminal, agents, calendar

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .tray: "tray.full"
        case .clipboard: "doc.on.clipboard"
        case .media: "music.note"
        case .terminal: "apple.terminal"
        case .agents: "sparkles"
        case .calendar: "calendar"
        }
    }

    var title: String {
        switch self {
        case .tray: L.t("Tray")
        case .clipboard: L.t("Clipboard")
        case .media: L.t("Media")
        case .terminal: L.t("Terminal")
        case .agents: L.t("Agents")
        case .calendar: L.t("Calendar")
        }
    }
}
