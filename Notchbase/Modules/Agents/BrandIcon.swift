import SwiftUI

enum BrandIcon {
    private static var cache: [String: NSImage] = [:]

    static func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        cache[name] = image
        return image
    }
}

struct BrandGlyph: View {
    var tool: AgentSession.Tool
    var size: CGFloat

    var body: some View {
        if let image = BrandIcon.image(named: tool.assetName) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: tool.symbol)
                .font(.system(size: size * 0.9, weight: .semibold))
        }
    }
}
