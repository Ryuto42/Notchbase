import SwiftUI

enum Theme {
    static let surface = Color.black

    static let card = Color.white.opacity(0.055)
    static let cardHover = Color.white.opacity(0.105)
    static let stroke = Color.white.opacity(0.09)
    static let hairline = Color.white.opacity(0.07)

    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.52)
    static let tertiaryText = Color.white.opacity(0.30)

    static let accent = Color(red: 0.55, green: 0.82, blue: 0.99)
    static let warm = Color(red: 0.99, green: 0.73, blue: 0.42)

    static let innerHighlight = LinearGradient(
        colors: [Color.white.opacity(0.05), Color.white.opacity(0)],
        startPoint: .top, endPoint: .bottom)

    static let body = LinearGradient(stops: [
        .init(color: .black, location: 0),
        .init(color: .black, location: 0.30),
        .init(color: .black.opacity(0.66), location: 0.68),
        .init(color: .black.opacity(0.30), location: 1),
    ], startPoint: .top, endPoint: .bottom)

    static let backdropMask = LinearGradient(stops: [
        .init(color: .clear, location: 0.18),
        .init(color: .black, location: 0.85),
    ], startPoint: .top, endPoint: .bottom)

    static let glassSheen = LinearGradient(
        colors: [Color.white.opacity(0.17), Color.white.opacity(0.05), Color.white.opacity(0.02)],
        startPoint: .top, endPoint: .bottom)

    static let glassEdge = LinearGradient(
        colors: [Color.white.opacity(0.45), Color.white.opacity(0.10), Color.white.opacity(0.20)],
        startPoint: .top, endPoint: .bottom)
}

enum Typo {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func digits(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

extension View {
    func cardBackground(hovering: Bool = false, radius: CGFloat = 10) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(hovering ? Theme.cardHover : Theme.card)
        }
        .cardRim(RoundedRectangle(cornerRadius: radius, style: .continuous),
                 strength: hovering ? 1.35 : 1)
    }
}
