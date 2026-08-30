import AppKit

final class PassthroughView: NSView {
    var activeRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard activeRect.contains(point) else { return nil }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
