import Foundation

/// The single state machine every Notchbase module hangs off of.
enum NotchState: Equatable {
    /// Invisible (real notch) or a small island (notchless display).
    case closed
    /// Full panel with the module shelf.
    case expanded
    /// Live activity strip (media, timer, HUD mirroring).
    case activity

    /// Only the expanded panel is allowed to steal key focus (needed by the terminal module).
    var acceptsKeyInput: Bool { self == .expanded }
}
