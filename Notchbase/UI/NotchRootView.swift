import SwiftUI

/// Named space the tab rail reports its hit rects in.
enum NotchCoordinateSpace {
    nonisolated static let root = "notchRoot"
}

struct NotchRootView: View {
    var model: NotchViewModel

    private var size: CGSize { model.bodySize }
    private var isOpen: Bool { model.state == .expanded }
    private var topRadius: CGFloat { Layout.topRadius(for: model.state) }

    /// One spring for both directions so opening and closing feel identical.
    private var stateAnimation: Animation { Motion.open }

    var body: some View {
        VStack(spacing: 0) {
            shape
            if isOpen {
                TabRailView(model: model)
                    .padding(.top, Layout.tabRailGap)
                    .transition(.offset(y: -14)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.82, anchor: .top)))
            }
            Spacer(minLength: 0)
        }
        .frame(width: Layout.containerSize.width, height: Layout.containerSize.height, alignment: .top)
        .coordinateSpace(.named(NotchCoordinateSpace.root))
        .animation(stateAnimation, value: model.state)
        .animation(Motion.content, value: model.tab)
    }

    /// No drop shadow: a soft shadow spreads non-zero alpha across the whole host window,
    /// which both looks like a smear under the panel and makes the window eat clicks.
    ///
    /// The body is a vertical gradient rather than flat black, with a behind-window blur
    /// underneath it, so the panel is opaque where it meets the notch and dissolves into
    /// the desktop at the bottom.
    private var shape: some View {
        let outline = NotchShape(topRadius: topRadius,
                                 bottomRadius: Layout.bottomRadius(for: model.state))
        let fadeHeight = Preferences.shared.bottomFade
            ? max(0, size.height - 120) * Preferences.shared.bottomFadeAmount
            : 0

        return ZStack {
            Color.black
                .overlay(alignment: .bottom) {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.34), location: 0.55),
                        .init(color: .black.opacity(0.74), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                    .frame(height: fadeHeight)
                    .blendMode(.destinationOut)
                }
                .compositingGroup()

            GlassPane()
                .frame(height: fadeHeight)
                .mask(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.85), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

            Theme.innerHighlight.opacity(isOpen ? 1 : 0)
            content
        }
        // Sized before it is clipped: a tab whose content is taller than `Layout.contentSize`
        // would otherwise stretch the black body past the shape the hit area is built from.
        .frame(width: size.width + 2 * topRadius, height: size.height)
        .clipShape(outline)
        .overlay { outline.stroke(Theme.hairline, lineWidth: isOpen ? 0.6 : 0) }
        // Shrunk into the notch when closed, so opening reads as the panel growing out of
        // the cutout rather than a rectangle appearing beneath it.
        .scaleEffect(x: model.state == .closed ? 0.74 : 1,
                     y: model.state == .closed ? 0.5 : 1,
                     anchor: .top)
        .opacity(model.state == .closed ? 0 : 1)
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            if isOpen {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, topRadius)
        // Everything below the notch strip slides up behind it on the way out, so the
        // content looks like it is being drawn back into the notch rather than fading.
        .transition(.offset(y: -26).combined(with: .opacity))
        .clipped()
        .animation(stateAnimation, value: model.state)
    }

    /// The strip level with the physical notch: usable only to its left and right.
    private var header: some View {
        HStack(spacing: 0) {
            headerSide(alignment: .leading)
            Spacer(minLength: model.metrics.notchSize.width)
            headerSide(alignment: .trailing)
        }
        .frame(height: model.metrics.notchSize.height)
    }

    private func headerSide(alignment: Alignment) -> some View {
        Group {
            switch model.state {
            case .activity:
                ActivityStripView(model: model, alignment: alignment)
            case .expanded:
                ExpandedHeaderView(model: model, alignment: alignment)
            case .closed:
                Color.clear
            }
        }
        .frame(width: model.sideWidth(for: size), alignment: alignment)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch model.tab {
        case .tray: TrayView(model: model)
        case .clipboard: ClipboardView(store: model.clipboard) { model.onClose?() }
        case .media: MediaView(model: model)
        case .terminal: TerminalPane()
        case .agents: AgentsView(monitor: model.agents) { model.onOpenProject?($0) }
        case .calendar: CalendarPane(store: model.calendar)
        }
    }
}

private struct ExpandedHeaderView: View {
    var model: NotchViewModel
    var alignment: Alignment

    var body: some View {
        if alignment == .leading {
            HStack(spacing: 6) {
                Text(model.tab.title.uppercased())
                    .font(Typo.rounded(9, .bold))
                    .tracking(0.9)
                    .foregroundStyle(Theme.tertiaryText)
                Spacer(minLength: 0)
            }
            .padding(.leading, 14)
        } else {
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                if let battery = model.battery.percentage {
                    HStack(spacing: 3) {
                        Image(systemName: model.battery.isCharging ? "bolt.fill" : "battery.50")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(battery)%")
                            .font(Typo.digits(9, .semibold))
                    }
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.trailing, 4)
                }
                GlyphButton(symbol: "gearshape.fill", size: 11) { model.onOpenSettings?() }
                GlyphButton(symbol: "xmark", size: 11) { model.onClose?() }
            }
            .padding(.trailing, 10)
        }
    }
}

/// Small circular icon button used in the header and module rows.
///
/// The visual circle stays small but the hit area is a full 26pt square: undersized targets
/// were the main reason clicks appeared to do nothing.
struct GlyphButton: View {
    var symbol: String
    var size: CGFloat = 11
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(hovering ? Theme.primaryText : Theme.secondaryText)
                .frame(width: 26, height: 26)
                .background { Circle().fill(hovering ? Theme.cardHover : .clear) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

/// Text button with a hit area that extends past the glyphs.
struct TextButton: View {
    var title: String
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typo.rounded(10.5, .semibold))
                .foregroundStyle(hovering ? Theme.primaryText : Theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { Capsule().fill(hovering ? Theme.cardHover : .clear) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}
