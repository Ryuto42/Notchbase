import Foundation

/// Incremental reader for an agent transcript.
///
/// Session logs are append-only JSONL that can reach several megabytes, so each file is read
/// once and then only from wherever the last read stopped.
final class TranscriptReader {
    private(set) var tokens = 0
    private(set) var title: String?
    /// True while the agent still owes a reply.
    private(set) var turnOpen = false
    /// Directory the session is working in, so a row can open the project.
    private(set) var directory: String?
    private var offset: UInt64 = 0
    private var lastSize: UInt64 = 0

    let url: URL
    let tool: AgentSession.Tool

    init(url: URL, tool: AgentSession.Tool) {
        self.url = url
        self.tool = tool
    }

    /// Consumes whatever has been appended since the previous call.
    func refresh() {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        if size < lastSize {
            // The file was truncated or replaced; start over.
            offset = 0
            tokens = 0
        }
        lastSize = size
        guard size > offset else { return }

        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }

        // Only consume up to the last complete line; the rest arrives next time.
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
        switch object["type"] as? String {
        case "user":
            // Either a prompt or a tool result — the model has to answer either way.
            turnOpen = true
        case "assistant":
            let content = (object["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
            // A turn that ends in a tool call is still going; anything else finishes it.
            turnOpen = content.contains { $0["type"] as? String == "tool_use" }
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

    private func consumeCodex(_ object: [String: Any]) {
        guard let payload = object["payload"] as? [String: Any] else { return }
        if directory == nil, let cwd = payload["cwd"] as? String, !cwd.isEmpty {
            directory = cwd
        }
        switch payload["type"] as? String {
        case "task_started": turnOpen = true
        case "task_complete", "agent_message", "token_count": turnOpen = false
        default: break
        }
        guard payload["type"] as? String == "token_count",
              let info = payload["info"] as? [String: Any],
              let total = info["total_token_usage"] as? [String: Any],
              let value = total["total_tokens"] as? Int else { return }
        // Codex reports a running total for the session rather than a per-message delta.
        tokens = value
    }
}
