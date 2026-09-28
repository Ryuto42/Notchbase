import Foundation

final class TranscriptReader {
    private(set) var tokens = 0
    private(set) var title: String?
    private(set) var turnOpen = false
    private(set) var interrupted = false
    private(set) var directory: String?
    private var backgroundTasks: Set<String> = []

    var hasBackgroundTasks: Bool { !backgroundTasks.isEmpty }

    private static let endReasons: Set<String> = ["end_turn", "stop_sequence", "max_tokens", "refusal"]
    private static let backgroundPrefixes = ["Async agent launched", "Command running in background", "Command did not complete within"]
    private var offset: UInt64 = 0
    private var lastSize: UInt64 = 0

    let url: URL
    let tool: AgentSession.Tool

    init(url: URL, tool: AgentSession.Tool) {
        self.url = url
        self.tool = tool
    }

    func refresh() {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        if size < lastSize {
            offset = 0
            tokens = 0
        }
        lastSize = size
        guard size > offset else { return }

        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }

        guard let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return }
        let consumable = data[data.startIndex...lastNewline]
        offset += UInt64(consumable.count)

        for line in consumable.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else {
                continue
            }
            switch tool {
            case .claude: consumeClaude(object)
            case .codex: consumeCodex(object)
            }
        }
    }

    private func consumeClaude(_ object: [String: Any]) {
        if directory == nil, let cwd = object["cwd"] as? String, !cwd.isEmpty {
            directory = cwd
        }
        let message = object["message"] as? [String: Any]
        let queued = [object["content"] as? String,
                      (object["attachment"] as? [String: Any])?["prompt"] as? String].compactMap { $0 }
        for body in queued {
            for id in Self.notifiedToolUses(in: body) { backgroundTasks.remove(id) }
        }
        switch object["type"] as? String {
        case "user":
            consumeClaudeUser(object, message: message)
        case "assistant":
            interrupted = false
            if let reason = message?["stop_reason"] as? String {
                turnOpen = !Self.endReasons.contains(reason)
            } else {
                let content = message?["content"] as? [[String: Any]] ?? []
                turnOpen = content.contains { $0["type"] as? String == "tool_use" }
            }
        default:
            break
        }
        if let custom = object["customTitle"] as? String, !custom.isEmpty {
            title = custom
        } else if let generated = object["aiTitle"] as? String, !generated.isEmpty {
            title = generated
        }
        guard let message = object["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else { return }
        let keys = ["input_tokens", "output_tokens", "cache_creation_input_tokens"]
        tokens += keys.reduce(0) { $0 + ((usage[$1] as? Int) ?? 0) }
    }

    private func consumeClaudeUser(_ object: [String: Any], message: [String: Any]?) {
        let content = message?["content"]
        let blocks = content as? [[String: Any]] ?? []
        let text = (content as? String) ?? blocks.compactMap { $0["text"] as? String }.joined()
        let results = blocks.filter { $0["type"] as? String == "tool_result" }.map { block in
            (id: block["tool_use_id"] as? String,
             text: (block["content"] as? String)
                ?? (block["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
                ?? "")
        }

        for body in [text] + results.map(\.text) {
            for id in Self.notifiedToolUses(in: body) { backgroundTasks.remove(id) }
        }
        if text.hasPrefix("[Request interrupted by user") {
            interrupted = true
            turnOpen = false
            return
        }
        for result in results {
            let head = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id = result.id, Self.backgroundPrefixes.contains(where: head.hasPrefix) {
                backgroundTasks.insert(id)
            }
        }
        interrupted = false
        turnOpen = true
    }

    private static func notifiedToolUses(in text: String) -> [String] {
        text.components(separatedBy: "<task-notification>").dropFirst().compactMap { capture("tool-use-id", in: $0) }
    }

    private static func capture(_ tag: String, in text: String) -> String? {
        guard let start = text.range(of: "<\(tag)>"),
              let end = text.range(of: "</\(tag)>", range: start.upperBound..<text.endIndex) else { return nil }
        return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func consumeCodex(_ object: [String: Any]) {
        guard let payload = object["payload"] as? [String: Any] else { return }
        if directory == nil, let cwd = payload["cwd"] as? String, !cwd.isEmpty {
            directory = cwd
        }
        switch payload["type"] as? String {
        case "task_started": turnOpen = true
        case "task_complete", "turn_aborted": turnOpen = false
        default: break
        }
        guard payload["type"] as? String == "token_count",
              let info = payload["info"] as? [String: Any],
              let total = info["total_token_usage"] as? [String: Any],
              let value = total["total_tokens"] as? Int else { return }
        tokens = value
    }
}
