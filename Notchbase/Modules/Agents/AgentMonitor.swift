import Foundation
import Observation

@Observable
final class AgentMonitor {
    struct Completion: Equatable {
        var title: String
        var tool: AgentSession.Tool
        var at: Date
    }

    private(set) var sessions: [AgentSession] = []

    func applyDemo(_ demo: [AgentSession]) { sessions = demo }
    private(set) var lastCompletion: Completion?

    @ObservationIgnored private var wasWorking: Set<String> = []

    @ObservationIgnored private var readers: [URL: TranscriptReader] = [:]
    @ObservationIgnored private var codexTitles: [String: String] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var stream: FSEventStreamRef?

    private let claudeRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/projects")
    private let codexRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/sessions")
    private let codexIndex = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/session_index.jsonl")

    var workingSessions: [AgentSession] { sessions.filter { $0.status == .working } }

    func recentCompletion(within seconds: TimeInterval = 25) -> Completion? {
        guard let completion = lastCompletion,
              Date().timeIntervalSince(completion.at) < seconds else { return nil }
        return completion
    }

    func start() {
        loadCodexTitles()
        scan()
        watch()
        let timer = Timer(timeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated { self.scan() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func watch() {
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let paths = [claudeRoot.path, codexRoot.path] as CFArray
        guard let stream = FSEventStreamCreate(nil, { _, info, _, _, _, _ in
            guard let info else { return }
            MainActor.assumeIsolated {
                Unmanaged<AgentMonitor>.fromOpaque(info).takeUnretainedValue().scan()
            }
        }, &context, paths, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1,
           FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    // MARK: - Scanning

    private func scan() {
        guard !Debug.isDemo else { return }
        let days = Double(max(1, Preferences.shared.agentHistoryDays))
        let cutoff = Date().addingTimeInterval(-60 * 60 * 24 * days)
        var found: [AgentSession] = []
        var live: Set<String> = []
        var subagents: [String: (modified: Date, working: Bool)] = [:]

        for url in transcripts(in: claudeRoot, modifiedAfter: cutoff) where Self.isSubagent(url) {
            guard let modified = modificationDate(of: url) else { continue }
            let reader = readers[url] ?? TranscriptReader(url: url, tool: .claude)
            readers[url] = reader
            reader.refresh()
            live.insert(url.path)
            let parent = url.deletingLastPathComponent().deletingLastPathComponent().path + ".jsonl"
            let working = (reader.turnOpen || reader.hasBackgroundTasks)
                && Date().timeIntervalSince(modified) < AgentSession.workingWindow
            let previous = subagents[parent]
            subagents[parent] = (max(previous?.modified ?? modified, modified), (previous?.working ?? false) || working)
        }

        for (root, tool) in [(claudeRoot, AgentSession.Tool.claude), (codexRoot, .codex)] {
            for url in transcripts(in: root, modifiedAfter: cutoff) where !Self.isSubagent(url) {
                guard let modified = modificationDate(of: url) else { continue }

                let reader = readers[url] ?? TranscriptReader(url: url, tool: tool)
                readers[url] = reader
                reader.refresh()
                live.insert(url.path)

                let children = subagents[url.path]
                var session = AgentSession(id: url.path,
                                           tool: tool,
                                           title: title(for: url, tool: tool, reader: reader),
                                           lastActivity: max(modified, children?.modified ?? modified),
                                           tokens: reader.tokens,
                                           directory: reader.directory)
                session.turnOpen = reader.turnOpen
                session.subagentsWorking = children?.working ?? false
                session.backgroundPending = reader.hasBackgroundTasks
                session.interrupted = reader.interrupted
                found.append(session)
            }
        }

        let sorted = found.sorted { $0.lastActivity > $1.lastActivity }
        if sorted != sessions { sessions = sorted }
        noteCompletions(in: sessions)
        readers = readers.filter { live.contains($0.key.path) }
    }

    private static func isSubagent(_ url: URL) -> Bool {
        url.deletingLastPathComponent().lastPathComponent == "subagents"
    }

    private func noteCompletions(in sessions: [AgentSession]) {
        let working = Set(sessions.filter { $0.status == .working }.map(\.id))
        let finished = wasWorking.subtracting(working)
        if let id = finished.first, let session = sessions.first(where: { $0.id == id }), !session.interrupted {
            lastCompletion = Completion(title: session.title, tool: session.tool, at: Date())
            Debug.log("completion: \(session.title)")
        }
        if !working.isEmpty || !wasWorking.isEmpty {
            Debug.log("working=\(working.count) was=\(wasWorking.count)")
        }
        wasWorking = working
    }

    private func transcripts(in root: URL, modifiedAfter cutoff: Date) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate, modified >= cutoff else { continue }
            results.append(url)
        }
        return results
    }

    private func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    // MARK: - Titles

    private func title(for url: URL, tool: AgentSession.Tool, reader: TranscriptReader) -> String {
        if let title = reader.title, !title.isEmpty { return title }
        switch tool {
        case .claude:
            let folder = url.deletingLastPathComponent().lastPathComponent
            return folder.split(separator: "-").last.map(String.init) ?? "Claude session"
        case .codex:
            let name = url.deletingPathExtension().lastPathComponent
            let id = name.split(separator: "-").suffix(5).joined(separator: "-")
            return codexTitles[id] ?? "Codex session"
        }
    }

    private func loadCodexTitles() {
        guard let data = try? Data(contentsOf: codexIndex),
              let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let id = object["id"] as? String,
                  let name = object["thread_name"] as? String else { continue }
            codexTitles[id] = name
        }
    }
}
