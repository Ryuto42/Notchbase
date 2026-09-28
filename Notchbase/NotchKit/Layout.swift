import CoreGraphics

enum Layout {
    static let pseudoNotchSize = CGSize(width: 190, height: 32)

    static let containerSize = CGSize(width: 680, height: 360)

    static let topCornerRadius: CGFloat = 22
    static let bottomCornerRadius: CGFloat = 26
    static let closedTopRadius: CGFloat = 7
    static let closedBottomRadius: CGFloat = 10

    static func topRadius(for state: NotchState) -> CGFloat {
        switch state {
        case .expanded: topCornerRadius
        case .activity: closedTopRadius
        case .closed: 0
        }
    }

    static func bottomRadius(for state: NotchState) -> CGFloat {
        state == .expanded ? bottomCornerRadius : closedBottomRadius
    }

    static let tabRailHeight: CGFloat = 40
    static let tabRailGap: CGFloat = 9

    static let contentSize = CGSize(width: 620, height: 208)

    static let activityExtraWidth: CGFloat = 62
    static func clockActivityExtraWidth(hourDigits: Int) -> CGFloat {
        [100, 130, 140][min(max(hourDigits, 0), 2)]
    }
    static let activityExtraHeight: CGFloat = 0

    static let hoverSlop: CGFloat = 3
    static let hoverSideSlop: CGFloat = 6

    static func interactiveSize(for state: NotchState, metrics: NotchMetrics, tab: NotchTab,
                                activityWidth: CGFloat) -> CGSize {
        let body = bodySize(for: state, metrics: metrics, tab: tab, activityWidth: activityWidth)
        guard state == .expanded else { return body }
        return CGSize(width: body.width, height: body.height + tabRailGap + tabRailHeight)
    }

    static func bodySize(for state: NotchState, metrics: NotchMetrics, tab: NotchTab,
                         activityWidth: CGFloat) -> CGSize {
        let notch = metrics.notchSize
        switch state {
        case .closed:
            return notch
        case .activity:
            return CGSize(width: notch.width + activityWidth,
                          height: notch.height + activityExtraHeight)
        case .expanded:
            return CGSize(width: max(contentSize.width, notch.width + 170),
                          height: notch.height + contentSize.height)
        }
    }
}
