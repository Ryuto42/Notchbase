import AppKit

/// Global pointer observation. Mouse-only event monitors need no Accessibility permission.
///
/// Hover is driven from here rather than from `NSTrackingArea` because the panel's hit
/// testing is clipped (see `PassthroughView`) and because AppKit does not deliver
/// `mouseEntered:` to windows during an active drag session.
final class PointerMonitor {
    var onMove: ((CGPoint) -> Void)?
    var onFileDragMove: ((CGPoint) -> Void)?
    var onFileDragEnd: (() -> Void)?
    var onClick: ((CGPoint) -> Void)?

    private var monitors: [Any] = []
    private var lastDragChangeCount = NSPasteboard(name: .drag).changeCount
    private var isFileDragging = false

    func start() {
        let moved = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
            MainActor.assumeIsolated { self.onMove?(NSEvent.mouseLocation) }
        }
        let dragged = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { _ in
            MainActor.assumeIsolated { self.handleDrag() }
        }
        let up = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            MainActor.assumeIsolated { self.endDrag() }
        }
        let down = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
            MainActor.assumeIsolated { self.onClick?(NSEvent.mouseLocation) }
        }
        monitors = [moved, dragged, up, down].compactMap { $0 }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    /// A drag session is detected by watching the drag pasteboard's change count: it bumps
    /// exactly once when a drag begins, and only file drags are interesting to us.
    private func handleDrag() {
        if !isFileDragging {
            let pasteboard = NSPasteboard(name: .drag)
            guard pasteboard.changeCount != lastDragChangeCount else { return }
            lastDragChangeCount = pasteboard.changeCount
            let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
            guard pasteboard.canReadObject(forClasses: [NSURL.self], options: options) else { return }
            isFileDragging = true
        }
        onFileDragMove?(NSEvent.mouseLocation)
    }

    private func endDrag() {
        guard isFileDragging else { return }
        isFileDragging = false
        onFileDragEnd?()
    }
}
