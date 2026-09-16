import SwiftUI

enum NotchCoordinateSpace {
    nonisolated static let root = "notchRoot"
}

struct NotchRootView: View {
    var model: NotchViewModel

    @Namespace private var island

    private var size: CGSize { model.bodySize }
    private var isOpen: Bool { model.state == .expanded }
    private var topRadius: CGFloat { Layout.topRadius(for: model.state) }

    private var stateAnimation: Animation {
        model.state == .expanded ? Motion.open : Motion.close
    }

    var body: some View {
        VStack(spacing: 0) {
            shape
            if isOpen {
                TabRailView(model: model)
                    .padding(.top, Layout.tabRailGap)
                    .transition(.offset(y: -10).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(width: Layout.containerSize.width, height: Layout.containerSize.height, alignment: .top)
        .coordinateSpace(.named(NotchCoordinateSpace.root))
        .animation(stateAnimation, value: model.state)
        .animation(Motion.content, value: model.tab)
    }

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
        .frame(width: max(size.width + 2 * topRadius, model.metrics.notchSize.width),
               height: max(size.height, model.metrics.notchSize.height))
        .clipShape(outline)
        .glassBezel(outline,
                    width: isOpen ? 7 : 3,
                    strength: isOpen ? 0.35 : 0,
                    fadeTop: model.metrics.notchSize.height / max(size.height, 1),
                    fadeBottom: fadeHeight / max(size.height, 1))
        .background(alignment: .top) {
            Rectangle()
                .fill(.black)
                .frame(width: model.metrics.notchSize.width,
                       height: model.metrics.notchSize.height)
        }
        .opacity(model.isVisible ? 1 : 0)
        .animation(nil, value: model.isVisible)
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            if isOpen {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.animation(.linear(duration: 0.09)))
            }
        }
        .padding(.horizontal, topRadius)
        .transition(.island)
        .clipped()
        .animation(stateAnimation, value: model.state)
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerSide(alignment: .leading)
            Spacer(minLength: model.metrics.notchSize.width)
            headerSide(alignment: .trailing)
        }
        .frame(height: model.metrics.notchSize.height)
    }

    private func headerSide(alignment: Alignment) -> some View {
        ZStack(alignment: alignment) {
            if model.state == .activity {
                ActivityStripView(model: model, alignment: alignment, island: island)
                    .transition(.opacity.animation(.linear(duration: 0.07)))
            }
            if isOpen {
                ExpandedHeaderView(model: model, alignment: alignment)
                    .transition(.opacity)
            }
        }
        .frame(width: model.sideWidth(for: size), alignment: alignment)
        .animation(stateAnimation, value: model.state)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch model.tab {
        case .tray: TrayView(model: model)
        case .clipboard: ClipboardView(store: model.clipboard) { model.onClose?() }
        case .media: MediaView(model: model, island: island)
        case .terminal: TerminalPane()
        case .agents: AgentsView(monitor: model.agents) { model.onOpenProject?($0) }
        case .calendar:
            CalendarPane(store: model.calendar)
                .onAppear { model.calendar.focusToday() }
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
