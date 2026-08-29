import SwiftUI

/// Every animation in the app, scaled by the user's chosen motion style.
enum Motion {
    private static var scale: Double { Preferences.shared.motionStyle.scale }

    private static func spring(_ response: Double, _ damping: Double) -> Animation {
        .spring(response: response * scale, dampingFraction: damping)
    }

    /// Opening and closing the panel.
    static var open: Animation { spring(0.40, 0.76) }
    /// Collapsed-state changes (the activity strip).
    static var morph: Animation { spring(0.26, 0.86) }
    /// Content appearing inside the panel.
    static var content: Animation { spring(0.17, 0.92) }
    /// Hover and press feedback. Must be near-instant or buttons feel unresponsive.
    static var quick: Animation { .easeOut(duration: 0.09 * scale) }
    /// Lyric column travelling to the next line, eased the way Apple Music does it.
    static var lyric: Animation { spring(0.62, 0.86) }
    /// The active lyric line growing into place.
    static var lyricEmphasis: Animation { spring(0.45, 0.80) }
}
