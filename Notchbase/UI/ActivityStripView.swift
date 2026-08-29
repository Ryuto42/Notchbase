import SwiftUI

/// Compact information flanking the notch while the panel is closed.
struct ActivityStripView: View {
    var model: NotchViewModel
    var alignment: Alignment

    var body: some View {
        Group {
            switch model.activity {
            case .agents: agents
            case .media: media
            case nil: Color.clear
            }
        }
        .id(model.activity)
        .transition(.asymmetric(
            insertion: .offset(y: 10).combined(with: .opacity),
            removal: .offset(y: -10).combined(with: .opacity)))
        .animation(Motion.content, value: model.activity)
    }

    // MARK: - Agents

    @ViewBuilder
    private var agents: some View {
        if let completion = model.agents.recentCompletion() {
            if alignment == .leading {
                BrandGlyph(tool: completion.tool, size: 17)
                    .foregroundStyle(Theme.primaryText)
                    .padding(.leading, 8)
                    .help(completion.title)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.36, green: 0.86, blue: 0.52))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 9)
                    .help(completion.title)
            }
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var media: some View {
        if let playing = model.media.current {
            if alignment == .leading {
                ArtworkView(image: model.media.artwork, size: 22, radius: 5.5)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .strokeBorder((model.media.artworkTint ?? Theme.accent).opacity(0.5),
                                          lineWidth: 1)
                    }
                    .padding(.leading, 8)
                    .help(playing.title)
            } else {
                AudioBarsView(isAnimating: playing.isPlaying)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 9)
                    .help("\(playing.title) — \(playing.artist)")
            }
        }
    }

}

/// Thin capsule progress used in the activity strip.
struct Meter: View {
    var value: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(tint)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Three bars that pulse while audio plays.
struct AudioBarsView: View {
    var isAnimating: Bool

    @State private var phase = false

    private let heights: [CGFloat] = [9, 4.5, 7]

    var body: some View {
        HStack(alignment: .center, spacing: 1.8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 2, height: phase ? heights[index] : heights[(index + 1) % 3])
            }
        }
        .frame(height: 10)
        .onAppear { animate() }
        .onChange(of: isAnimating) { _, _ in animate() }
    }

    private func animate() {
        guard isAnimating else {
            withAnimation(.easeOut(duration: 0.2)) { phase = false }
            return
        }
        withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
            phase = true
        }
    }
}

struct ArtworkView: View {
    var image: NSImage?
    var size: CGFloat
    var radius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Theme.card)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.38, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        }
    }
}

/// Empty / error state shared by every module.
struct PlaceholderView: View {
    var symbol: String
    var title: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(Theme.tertiaryText)
            Text(title)
                .font(Typo.rounded(11.5, .semibold))
                .foregroundStyle(Theme.secondaryText)
            if let detail {
                Text(detail)
                    .font(Typo.rounded(10))
                    .foregroundStyle(Theme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typo.rounded(11.5, .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background { Capsule().fill(Theme.cardHover) }
                        .overlay { Capsule().strokeBorder(Theme.stroke, lineWidth: 0.5) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum Format {
    static func time(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    static func tokens(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0fk", Double(value) / 1_000) }
        return "\(value)"
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func relative(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86_400))d"
    }
}
