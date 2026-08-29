import SwiftUI

/// Lyrics pane.
///
/// The column is translated by a *fractional* line number rather than snapped to whole
/// lines, so it glides continuously with the playhead instead of cutting on each timestamp.
/// Dragging takes over temporarily for reading ahead, then hands back to the playhead.
struct LyricsTickerView: View {
    var controller: LyricsController
    var position: Double

    private static let lineHeight: CGFloat = 19
    private static let visibleLines: CGFloat = 3.2

    @State private var manualOffset: CGFloat?
    @State private var manualUntil = Date.distantPast

    private var index: Int? { controller.index(at: position) }

    var body: some View {
        Group {
            switch controller.status {
            case .synced where !controller.lines.isEmpty:
                synced
            case .plainOnly:
                plain
            default:
                status
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.lineHeight * Self.visibleLines, alignment: .top)
        .clipped()
    }

    // MARK: - Time-synced

    /// Line the column is parked on. Whole lines, animated: interpolating the position
    private var anchor: Int { max(0, index ?? 0) }

    private var offset: CGFloat {
        if let manualOffset, Date() < manualUntil { return manualOffset }
        return -CGFloat(max(0, anchor - 1)) * Self.lineHeight
    }

    private var synced: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(controller.lines.enumerated()), id: \.offset) { line, entry in
                let distance = line - anchor
                Text(entry.text.isEmpty ? "♪" : entry.text)
                    .font(.system(size: 13.5, weight: distance == 0 ? .semibold : .regular))
                    .foregroundStyle(Theme.primaryText.opacity(opacity(for: distance)))
                    .scaleEffect(distance == 0 ? 1.08 : 0.96, anchor: .leading)
                    .lineLimit(1)
                    .frame(height: Self.lineHeight, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(Motion.lyricEmphasis, value: distance == 0)
            }
        }
        .offset(y: offset)
        .animation(Motion.lyric, value: offset)
        .frame(height: Self.lineHeight * Self.visibleLines, alignment: .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    let base = manualOffset ?? -CGFloat(max(0, anchor - 1)) * Self.lineHeight
                    manualOffset = base + value.translation.height / 6
                    manualUntil = Date().addingTimeInterval(6)
                }
                .onEnded { _ in manualUntil = Date().addingTimeInterval(6) }
        )
        .onChange(of: anchor) { _, _ in
            if Date() >= manualUntil { manualOffset = nil }
        }
    }

    private func opacity(for distance: Int) -> Double {
        switch distance {
        case 0: 1
        case -1: 0.22
        case 1: 0.40
        case 2: 0.22
        case ..<(-1): 0.06
        default: 0.12
        }
    }

    // MARK: - Plain text

    private var plain: some View {
        ScrollView(showsIndicators: false) {
            Text(controller.plain ?? "")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.primaryText.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Everything else

    private var status: some View {
        HStack(spacing: 7) {
            Image(systemName: statusSymbol)
                .font(.system(size: 13, weight: .light))
            Text(statusText)
                .font(.system(size: 12))
        }
        .foregroundStyle(Theme.tertiaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var statusSymbol: String {
        switch controller.status {
        case .loading: "ellipsis"
        case .instrumental: "music.quarternote.3"
        default: "quote.bubble"
        }
    }

    private var statusText: String {
        switch controller.status {
        case .loading: L.t(L.t("Looking for lyrics…"))
        case .instrumental: L.t(L.t("Marked instrumental on LRCLIB"))
        case .notFound: L.t(L.t("LRCLIB has no lyrics for this track"))
        default: ""
        }
    }
}
