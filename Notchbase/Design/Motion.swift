import SwiftUI

enum Motion {
    private static var scale: Double { Preferences.shared.motionStyle.scale }

    private static func spring(_ duration: Double, _ bounce: Double) -> Animation {
        .spring(duration: duration * scale, bounce: bounce)
    }

    // MARK: - The panel

    static var breath: Animation { spring(0.26, 0.34) }
    static var breathOut: Animation { spring(0.30, 0.12) }
    static var open: Animation { spring(0.42, 0.10) }
    static var close: Animation { spring(0.34, 0) }

    // MARK: - Inside the panel

    static var content: Animation { spring(0.28, 0.08) }
    static var withdraw: Animation { .easeIn(duration: 0.18 * scale) }
    static var settle: Animation { .easeOut(duration: 0.16 * scale).delay(0.16 * scale) }
    static var morph: Animation { spring(0.30, 0.10) }
    static var glass: Animation { spring(0.5, 0.3) }
    static var quick: Animation { .easeOut(duration: 0.09 * scale) }
    static var lyric: Animation { spring(0.7, 0.2) }
    static var lyricEmphasis: Animation { spring(0.5, 0.3) }
}
