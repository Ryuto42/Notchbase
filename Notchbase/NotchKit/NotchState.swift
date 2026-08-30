import Foundation

enum NotchState: Equatable {
    case closed
    case expanded
    case activity

    var acceptsKeyInput: Bool { self == .expanded }
}
