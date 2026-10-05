import SwiftUI

struct LiquidGlass {
    enum Variant {
        case regular, dark

        init(_ scheme: ColorScheme) {
            self = scheme == .dark ? .dark : .regular
        }
    }

    var radius: CGFloat
    var bevel: CGFloat = 8
    var edgeHighlight: Double
    var specular: Double
    var fresnel: Double
    var body: Double

    init(_ variant: Variant, radius: CGFloat, bevel: CGFloat = 8, hovering: Bool = false, rim: Double = 1) {
        self.radius = radius
        self.bevel = bevel
        switch variant {
        case .regular:
            edgeHighlight = hovering ? 0.45 : 0.32
            specular = hovering ? 0.30 : 0.22
            fresnel = 0.55
            body = hovering ? 0.10 : 0.07
        case .dark:
            edgeHighlight = hovering ? 0.28 : 0.18
            specular = hovering ? 0.16 : 0.10
            fresnel = 0.30
            body = hovering ? 0.085 : 0.045
        }
        edgeHighlight *= rim
        specular *= rim
        fresnel *= rim
    }

    var shader: Shader {
        ShaderLibrary.liquidGlass(.boundingRect,
                                  .float(radius),
                                  .float(bevel),
                                  .float(edgeHighlight),
                                  .float(specular),
                                  .float(fresnel),
                                  .float(body))
    }
}

extension View {
    func liquidGlass(_ glass: LiquidGlass) -> some View {
        background {
            Rectangle()
                .fill(glass.shader)
                .allowsHitTesting(false)
        }
    }
}
