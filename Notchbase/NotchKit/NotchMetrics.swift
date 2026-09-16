import AppKit

struct NotchMetrics: Equatable {
    let screenFrame: CGRect
    let notchSize: CGSize
    let notchCenterX: CGFloat
    let hasRealNotch: Bool

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
                                    notchCenterX: left.maxX + (right.minX - left.maxX) / 2,
                                    hasRealNotch: true)
            }
        }

        return NotchMetrics(screenFrame: frame,
                            notchSize: Layout.pseudoNotchSize,
                            notchCenterX: frame.midX,
                            hasRealNotch: false)
    }

    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}
