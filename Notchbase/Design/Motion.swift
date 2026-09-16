import SwiftUI

enum Motion {
    private static var scale: Double { Preferences.shared.motionStyle.scale }

    private static var bounceScale: Double { Preferences.shared.motionBounce }

    private static func spring(_ duration: Double, _ bounce: Double) -> Animation {
        .spring(duration: duration * scale, bounce: min(0.7, bounce * bounceScale))
    }

    // MARK: - The panel

    static var stateDuration: Double { 0.40 * scale }
    static var open: Animation { spring(0.40, 0.06) }
    static var close: Animation { spring(0.40, 0.06) }

    // MARK: - Inside the panel

    static var content: Animation { spring(0.22, 0.08) }
    static var withdraw: Animation { .easeIn(duration: 0.18 * scale) }
    static var morph: Animation { spring(0.30, 0.10) }
    static var glass: Animation { spring(0.40, 0.06) }
    static var quick: Animation { .easeOut(duration: 0.09 * scale) }
    static var lyric: Animation { spring(0.7, 0.2) }
    static var lyricEmphasis: Animation { spring(0.5, 0.3) }
}

struct IslandMorph: ViewModifier {
    var active: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 0.9 : 1, anchor: .top)
            .blur(radius: active ? 7 : 0)
            .opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    static var island: AnyTransition {
        .modifier(active: IslandMorph(active: true), identity: IslandMorph(active: false))
    }
}
