import SwiftUI

struct TabRailView: View {
    var model: NotchViewModel

    @Namespace private var glass

    private var tabs: [NotchTab] { Preferences.shared.visibleTabs }
    private var fade: Double { Preferences.shared.tabRailOpacity }

    var body: some View {
        content
            .background { bar }
            .animation(Motion.glass, value: model.tab)
    }

    @ViewBuilder
    private var content: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { row }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                TabButton(tab: tab,
                          isSelected: model.tab == tab,
                          isHovered: model.hoveredTab == tab,
                          glass: glass) {
                    model.tab = tab
                } report: { frame in
                    model.tabFrames[tab] = frame
                }
            }
        }
        .padding(.horizontal, 5)
        .frame(height: Layout.tabRailHeight)
    }

    private var bar: some View {
        ZStack {
            BackdropView().saturation(1.5)
            Color.black.opacity(0.42)
            LinearGradient(colors: [Color.white.opacity(0.08), .clear],
                           startPoint: .top, endPoint: .center)
        }
        .clipShape(Capsule())
        .cardRim(Capsule(), strength: 0.9)
        .opacity(fade)
    }
}

private struct TabButton: View {
    var tab: NotchTab
    var isSelected: Bool
    var isHovered: Bool
    var glass: Namespace.ID
    var select: () -> Void
    var report: (CGRect) -> Void

    private var fade: Double { Preferences.shared.tabRailOpacity }
    private var showsLabel: Bool { isSelected && Preferences.shared.showTabLabels }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 12.5, weight: .semibold))
                if showsLabel {
                    Text(tab.title)
                        .font(Typo.rounded(11.5, .semibold))
                        .fixedSize()
                }
            }
            .foregroundStyle(Color.white.opacity(isSelected ? 1 : (isHovered ? 0.86 : 0.6)))
            .padding(.horizontal, showsLabel ? 14 : 0)
            .frame(width: showsLabel ? nil : 46, height: Layout.tabRailHeight - 8)
            .modifier(Lens(isSelected: isSelected, isHovered: isHovered, tab: tab, glass: glass))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(NotchCoordinateSpace.root))
        } action: { frame in
            report(frame)
        }
        .animation(Motion.quick, value: isHovered)
    }
}

private struct Lens: ViewModifier {
    var isSelected: Bool
    var isHovered: Bool
    var tab: NotchTab
    var glass: Namespace.ID

    private var fade: Double { Preferences.shared.tabRailOpacity }

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), isSelected {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
                .glassEffectID("selection", in: glass)
                .overlay {
                    Capsule()
                        .strokeBorder(Bezel.specular(1.4 * fade), lineWidth: 0.9)
                        .allowsHitTesting(false)
                }
        } else {
            content.background {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.10 * fade))
                        .cardRim(Capsule(), strength: 1.5 * fade)
                } else if isHovered {
                    Capsule().fill(Color.white.opacity(0.06 * fade))
                }
            }
        }
    }
}
