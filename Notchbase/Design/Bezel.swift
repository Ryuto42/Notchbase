import SwiftUI

enum Bezel {
    static func specular(_ strength: Double) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.30 * strength), location: 0.00),
            .init(color: .white.opacity(0.13 * strength), location: 0.22),
            .init(color: .white.opacity(0.04 * strength), location: 0.52),
            .init(color: .white.opacity(0.17 * strength), location: 0.86),
            .init(color: .white.opacity(0.07 * strength), location: 1.00),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func refraction(_ strength: Double) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.18 * strength), location: 0.00),
            .init(color: .white.opacity(0.04 * strength), location: 0.45),
            .init(color: .white.opacity(0.09 * strength), location: 1.00),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    func glassBezel<S: InsettableShape>(_ shape: S,
                                        width: CGFloat = 6,
                                        strength: Double = 1,
                                        fadeTop: Double = 0,
                                        fadeBottom: Double = 0) -> some View {
        overlay {
            ZStack {
                shape
                    .strokeBorder(Bezel.refraction(strength), lineWidth: width)
                    .blur(radius: width * 0.6)

                shape
                    .inset(by: width * 0.32)
                    .strokeBorder(Color.black.opacity(0.34 * strength), lineWidth: 0.9)
                    .blur(radius: 0.8)

                shape
                    .strokeBorder(Bezel.specular(strength), lineWidth: 0.9)
            }
            .mask {
                LinearGradient(stops: [
                    .init(color: .black.opacity(fadeTop > 0 ? 0 : 1), location: 0),
                    .init(color: .black, location: fadeTop),
                    .init(color: .black, location: max(fadeTop, 1 - fadeBottom)),
                    .init(color: .black.opacity(fadeBottom > 0 ? 0 : 1), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
        }
    }

    func cardRim<S: InsettableShape>(_ shape: S, strength: Double = 1) -> some View {
        overlay {
            shape
                .strokeBorder(LinearGradient(stops: [
                    .init(color: .white.opacity(0.20 * strength), location: 0),
                    .init(color: .white.opacity(0.06 * strength), location: 0.5),
                    .init(color: .white.opacity(0.11 * strength), location: 1),
                ], startPoint: .top, endPoint: .bottom), lineWidth: 0.6)
                .allowsHitTesting(false)
        }
    }
}
