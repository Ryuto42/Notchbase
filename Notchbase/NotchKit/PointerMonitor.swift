import AppKit

final class PointerMonitor {
    var onMove: ((CGPoint) -> Void)?
    var onFileDragMove: ((CGPoint) -> Void)?
    var onFileDragEnd: (() -> Void)?
    var onClick: ((CGPoint) -> Void)?

    private var monitors: [Any] = []
    private var consumedChangeCount = NSPasteboard(name: .drag).changeCount
    private var rejectedChangeCount = 0
    private var isFileDragging = false

    func start() {
        let moved = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
            MainActor.assumeIsolated {
                if self.isFileDragging, NSEvent.pressedMouseButtons & 1 == 0 { self.endDrag() }
                self.onMove?(NSEvent.mouseLocation)
            }
        }
        let dragged = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { _ in
            MainActor.assumeIsolated { self.handleDrag() }
        }
        let up = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            MainActor.assumeIsolated { self.endDrag() }
        }
        let down = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
            MainActor.assumeIsolated {
                self.endDrag()
                self.onClick?(NSEvent.mouseLocation)
            }
        }
        monitors = [moved, dragged, up, down].compactMap { $0 }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func handleDrag() {
        if !isFileDragging {
            let pasteboard = NSPasteboard(name: .drag)
            guard pasteboard.changeCount != consumedChangeCount,
                  pasteboard.changeCount != rejectedChangeCount else { return }
            let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
            guard pasteboard.canReadObject(forClasses: [NSURL.self], options: options) else {
                if pasteboard.types?.isEmpty == false {
                    rejectedChangeCount = pasteboard.changeCount
                }
                return
            }
            isFileDragging = true
        }
        onFileDragMove?(NSEvent.mouseLocation)
    }

    private func endDrag() {
        consumedChangeCount = NSPasteboard(name: .drag).changeCount
        guard isFileDragging else { return }
        isFileDragging = false
        onFileDragEnd?()
    }
}
