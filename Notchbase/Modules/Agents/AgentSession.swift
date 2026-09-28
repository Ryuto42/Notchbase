import Foundation

struct AgentSession: Identifiable, Hashable {
    enum Tool: String, Hashable, CaseIterable {
        case claude = "Claude"
        case codex = "Codex"

        var symbol: String {
            switch self {
            case .claude: "sparkles"
            case .codex: "chevron.left.forwardslash.chevron.right"
            }
        }

        var command: String {
            switch self {
            case .claude: "claude"
            case .codex: "codex"
            }
        }

        func deepLink(for directory: String) -> URL? {
            let encoded = directory.addingPercentEncoding(
                withAllowedCharacters: .alphanumerics.union(.init(charactersIn: "-._~/"))) ?? directory
            switch self {
            case .claude:
                return URL(string: "claude://code/new?folder=\(encoded)&source=notchbase")
            case .codex:
                return URL(string: "codex://threads/new?cwd=\(encoded)")
            }
        }

        var appBundleID: String {
            switch self {
            case .claude: "com.anthropic.claudefordesktop"
            case .codex: "com.openai.chat"
            }
        }

        var assetName: String {
            switch self {
            case .claude: "brand-claude"
            case .codex: "brand-openai"
            }
        }
    }

    enum Status {
        case working, waiting, finished
    }

    let id: String
    var tool: Tool
    var title: String
    var lastActivity: Date
    var tokens: Int
    var directory: String?

    var turnOpen = false
    var backgroundPending = false
    var interrupted = false

    var status: Status {
        let age = Date().timeIntervalSince(lastActivity)
        if turnOpen && age < 900 { return .working }
        if backgroundPending && age < 3600 { return .working }
        if age < 1800 { return .waiting }
        return .finished
    }
}
