import AppKit

struct NotchMetrics: Equatable {
    let screenFrame: CGRect
    let notchSize: CGSize
    let hasRealNotch: Bool

    var notchCenterX: CGFloat { screenFrame.midX }

    static func measure(_ screen: NSScreen) -> NotchMetrics {
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top

        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = frame.width - left.width - right.width
            if width > 1 {
                return NotchMetrics(screenFrame: frame,
                                    notchSize: CGSize(width: width, height: topInset),
                                    hasRealNotch: true)
            }
        }

        return NotchMetrics(screenFrame: frame,
                            notchSize: Layout.pseudoNotchSize,
                            hasRealNotch: false)
    }

    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}
