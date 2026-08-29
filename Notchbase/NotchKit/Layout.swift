import CoreGraphics

enum Layout {
    /// Used on displays without a real notch.
    static let pseudoNotchSize = CGSize(width: 190, height: 32)

    /// The always-on transparent host window. Content is anchored top-center inside it.
    static let containerSize = CGSize(width: 680, height: 360)

    /// Corner radii differ by state: the flare that joins the panel to the screen edge is
    /// generous when open, but stays close to the hardware notch's own radius when closed.
    static let topCornerRadius: CGFloat = 22
    static let bottomCornerRadius: CGFloat = 26
    static let closedTopRadius: CGFloat = 7
    static let closedBottomRadius: CGFloat = 10

    static func topRadius(for state: NotchState) -> CGFloat {
        state == .expanded ? topCornerRadius : closedTopRadius
    }

    static func bottomRadius(for state: NotchState) -> CGFloat {
        state == .expanded ? bottomCornerRadius : closedBottomRadius
    }

    /// The tab switcher floats free below the panel, so it is not part of the black body.
    static let tabRailHeight: CGFloat = 40
    static let tabRailGap: CGFloat = 9

    /// Every tab shares one content size, so switching tabs never resizes the panel.
    static let contentSize = CGSize(width: 620, height: 208)



    static let activityExtraWidth: CGFloat = 62
    /// The activity strip never grows past the notch: it lives in the menu bar and any
    /// extra height would hang into the content below.
    static let activityExtraHeight: CGFloat = 0

    /// How far below / beside the notch the pointer may sit and still count as hovering.
    /// Kept small on purpose — see `NotchController.hoverZone`.
    static let hoverSlop: CGFloat = 3
    static let hoverSideSlop: CGFloat = 6

    /// Region the panel accepts the pointer in — the black body plus the floating tab rail.
    static func interactiveSize(for state: NotchState, metrics: NotchMetrics, tab: NotchTab) -> CGSize {
        let body = bodySize(for: state, metrics: metrics, tab: tab)
        guard state == .expanded else { return body }
        return CGSize(width: body.width, height: body.height + tabRailGap + tabRailHeight)
    }

    /// Visible body size (excluding the flared top corners) for a given state.
    static func bodySize(for state: NotchState, metrics: NotchMetrics, tab: NotchTab) -> CGSize {
        let notch = metrics.notchSize
        switch state {
        case .closed:
            return notch
        case .activity:
            return CGSize(width: notch.width + activityExtraWidth,
                          height: notch.height + activityExtraHeight)
        case .expanded:
            return CGSize(width: max(contentSize.width, notch.width + 170),
                          height: notch.height + contentSize.height)
        }
    }
}
