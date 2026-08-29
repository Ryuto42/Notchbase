import SwiftUI

/// Floating tab switcher below the panel. It sits over the desktop rather than on the black
/// body, so it is built from a behind-window blur plus a sheen and a bright edge — the
/// "glass pill" look.
struct TabRailView: View {
    var model: NotchViewModel

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Preferences.shared.visibleTabs) { tab in
                TabButton(tab: tab,
                          isSelected: model.tab == tab,
                          isHovered: model.hoveredTab == tab,
                          namespace: indicator) {
                    model.tab = tab
                } report: { frame in
                    model.tabFrames[tab] = frame
                }
            }
        }
        .padding(.horizontal, 5)
        .frame(height: Layout.tabRailHeight)
        // The glass sits in a background layer rather than wrapping the buttons, so it can
        // be faded without taking the icons and labels with it.
        .background {
            Color.clear
                .glassBackground(in: Capsule(), clear: Preferences.shared.clearGlassRail)
                .opacity(Preferences.shared.tabRailOpacity)
        }
        .animation(Motion.content, value: model.tab)
    }
}

private struct TabButton: View {
    var tab: NotchTab
    var isSelected: Bool
    var isHovered: Bool
    var namespace: Namespace.ID
    var select: () -> Void
    var report: (CGRect) -> Void

    /// Scales the button fills alongside the rail's glass so one slider covers the lot.
    private var fade: Double { Preferences.shared.tabRailOpacity }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 12.5, weight: .semibold))
                if isSelected, Preferences.shared.showTabLabels {
                    Text(tab.title)
                        .font(Typo.rounded(11.5, .semibold))
                        .fixedSize()
                }
            }
            .foregroundStyle(Color.white.opacity(isSelected ? 0.9 : (isHovered ? 0.62 : 0.36)))
            .padding(.horizontal, isSelected && Preferences.shared.showTabLabels ? 13 : 0)
            .frame(width: isSelected && Preferences.shared.showTabLabels ? nil : 46,
                   height: Layout.tabRailHeight - 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.085 * fade))
                        .overlay {
                            Capsule().strokeBorder(LinearGradient(
                                colors: [Color.white.opacity(0.30 * fade), Color.white.opacity(0.07 * fade)],
                                startPoint: .top, endPoint: .bottom), lineWidth: 0.7)
                        }
                        .matchedGeometryEffect(id: "tab", in: namespace)
                } else if isHovered {
                    Capsule().fill(Color.white.opacity(0.055 * fade))
                }
            }
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
