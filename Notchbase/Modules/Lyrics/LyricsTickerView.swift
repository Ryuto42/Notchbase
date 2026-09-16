import SwiftUI

struct LyricsTickerView: View {
    var controller: LyricsController
    var position: Double
    var onSeek: (Double) -> Void

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

    private var anchor: Int { max(0, index ?? 0) }

    private var syncedOffset: CGFloat {
        -CGFloat(max(0, anchor - 1)) * Self.lineHeight
    }

    private var offset: CGFloat {
        if let manualOffset, Date() < manualUntil { return manualOffset }
        return syncedOffset
    }

    private var minOffset: CGFloat {
        -max(0, CGFloat(controller.lines.count) - Self.visibleLines) * Self.lineHeight
    }

    private func scroll(by delta: CGFloat) {
        manualOffset = min(0, max(minOffset, (manualOffset ?? syncedOffset) + delta))
        manualUntil = Date().addingTimeInterval(6)
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        manualOffset = nil
                        manualUntil = .distantPast
                        onSeek(entry.time - Preferences.shared.lyricsOffset)
                    }
                    .animation(Motion.lyricEmphasis, value: distance == 0)
            }
        }
        .offset(y: offset)
        .animation(Motion.lyric, value: offset)
        .frame(height: Self.lineHeight * Self.visibleLines, alignment: .top)
        .contentShape(Rectangle())
        .overlay { ScrollWheelCatcher { scroll(by: $0) } }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in scroll(by: value.translation.height / 6) }
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

private struct ScrollWheelCatcher: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView { CatcherView(onScroll: onScroll) }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CatcherView)?.onScroll = onScroll
    }

    private final class CatcherView: NSView {
        var onScroll: (CGFloat) -> Void
        private var monitor: Any?

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
                return
            }
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                let local = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(local) else { return event }
                let delta = event.hasPreciseScrollingDeltas
                    ? event.scrollingDeltaY
                    : event.scrollingDeltaY * 6
                self.onScroll(delta)
                return nil
            }
        }
    }
}
