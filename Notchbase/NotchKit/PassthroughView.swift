import AppKit

/// The panel spans a large transparent area, so hit testing has to be clipped to the
/// currently visible body — otherwise the window would swallow menu bar and desktop clicks.
final class PassthroughView: NSView {
    /// In panel content coordinates (bottom-left origin).
    var activeRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard activeRect.contains(point) else { return nil }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
