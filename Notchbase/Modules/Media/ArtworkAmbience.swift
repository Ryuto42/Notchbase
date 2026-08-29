import AppKit
import SwiftUI
import CoreImage

/// Average colour of the artwork, used for the warm wash at the bottom of the player.
enum ArtworkAmbience {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func tint(for image: NSImage?) -> Color? {
        guard let image,
              let tiff = image.tiffRepresentation,
              let input = CIImage(data: tiff) else { return nil }

        let parameters: [String: Any] = [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: input.extent),
        ]
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: parameters),
              let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output,
                       toBitmap: &pixel,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)

        // Push saturation up and clamp brightness so dark covers still glow a little.
        let base = NSColor(red: CGFloat(pixel[0]) / 255,
                           green: CGFloat(pixel[1]) / 255,
                           blue: CGFloat(pixel[2]) / 255,
                           alpha: 1)
        guard let hsb = base.usingColorSpace(.sRGB) else { return nil }
        let saturation = min(0.75, hsb.saturationComponent * 1.15 + 0.05)
        let brightness = min(0.70, max(0.32, hsb.brightnessComponent * 1.1))
        return Color(hue: Double(hsb.hueComponent),
                     saturation: Double(saturation),
                     brightness: Double(brightness))
    }
}
