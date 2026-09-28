import SwiftUI

struct AgentsView: View {
    var monitor: AgentMonitor
    var openProject: (AgentSession) -> Void

    var body: some View {
        Group {
            if monitor.sessions.isEmpty {
                PlaceholderView(symbol: "sparkles",
                                title: L.t("No recent agent sessions"),
                                detail: L.t("Claude Code and Codex transcripts from the last three days show up here."))
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(monitor.sessions) { session in
                            AgentRow(session: session, open: { openProject(session) })
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(.bottom, 4)
    }
}

private struct AgentRow: View {
    var session: AgentSession
    var open: () -> Void

    @State private var hovering = false

    private var folder: String? {
        session.directory.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 9) {
                StatusDot(status: session.status)

                BrandGlyph(tool: session.tool, size: 13)
                    .foregroundStyle(session.tool == .claude ? Theme.warm : Theme.primaryText)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 0) {
                    Text(session.title)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                    if let folder {
                        Text(folder)
                            .font(Typo.rounded(9.5))
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if hovering, session.directory != nil {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    Text(Format.tokens(session.tokens))
                        .font(Typo.digits(10))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Text(Format.relative(session.lastActivity))
                    .font(Typo.digits(10))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .cardBackground(hovering: hovering, radius: 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(session.directory == nil)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
        .help(session.directory ?? session.title)
        .contextMenu {
            if let directory = session.directory {
                Button(L.fill("Resume in %@", session.tool.rawValue), action: open)
                Button(L.t("Open in Finder")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: directory))
                }
            }
        }
    }
}

struct StatusDot: View {
    var status: AgentSession.Status

    @State private var pulsing = false

    private var color: Color {
        switch status {
        case .working: Color(red: 0.36, green: 0.86, blue: 0.52)
        case .waiting: Theme.warm.opacity(0.7)
        case .finished: Theme.tertiaryText
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay {
                if status == .working {
                    Circle()
                        .stroke(color, lineWidth: 1.5)
                        .scaleEffect(pulsing ? 2.4 : 1)
                        .opacity(pulsing ? 0 : 0.8)
                }
            }
            .onAppear {
                guard status == .working else { return }
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
    }
}
