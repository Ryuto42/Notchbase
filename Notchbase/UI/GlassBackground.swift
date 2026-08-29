import SwiftUI

/// Liquid Glass surface for the floating tab rail.
///
/// macOS 26 ships the real thing, which samples and refracts what is behind the window and
/// reacts to the pointer. Older systems fall back to a hand-built approximation: a
/// behind-window blur with the saturation pushed up, a thin specular rim and a top highlight.
struct GlassBackground<S: InsettableShape>: ViewModifier {
    var shape: S
    /// `.clear` glass lets far more of the desktop through than `.regular`.
    var isClear = false

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(isClear ? .clear.interactive() : .regular.interactive(), in: shape)
        } else {
            content
                .background {
                    ZStack {
                        BackdropView()
                            .saturation(1.8)
                            .brightness(0.03)
                        Color.white.opacity(isClear ? 0.02 : 0.04)
                        LinearGradient(colors: [Color.white.opacity(isClear ? 0.10 : 0.16), .clear],
                                       startPoint: .top, endPoint: .center)
                    }
                    .clipShape(shape)
                }
                .overlay {
                    shape
                        .strokeBorder(LinearGradient(
                            colors: [Color.white.opacity(0.55),
                                     Color.white.opacity(0.12),
                                     Color.white.opacity(0.28)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.8)
                }
        }
    }
}

extension View {
    func glassBackground<S: InsettableShape>(in shape: S, clear: Bool = false) -> some View {
        modifier(GlassBackground(shape: shape, isClear: clear))
    }
}

/// A pane of glass with nothing behind it, for masking over part of a surface.
struct GlassPane: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.clear, in: Rectangle())
        } else {
            BackdropView().saturation(1.6)
        }
    }
}
