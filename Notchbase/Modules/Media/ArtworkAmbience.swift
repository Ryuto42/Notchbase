import AppKit
import SwiftUI
import CoreImage

enum ArtworkAmbience {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func accent(for image: NSImage?) -> Color? {
        guard let image,
              let tiff = image.tiffRepresentation,
              let input = CIImage(data: tiff) else { return nil }

        let extent = input.extent
        let steps = 4
        var best: (score: CGFloat, colour: NSColor)?

        for row in 0..<steps {
            for column in 0..<steps {
                let cell = CGRect(x: extent.minX + extent.width * CGFloat(column) / CGFloat(steps),
                                  y: extent.minY + extent.height * CGFloat(row) / CGFloat(steps),
                                  width: extent.width / CGFloat(steps),
                                  height: extent.height / CGFloat(steps))
                guard let colour = average(of: input, in: cell)?.usingColorSpace(.sRGB) else { continue }
                let brightness = colour.brightnessComponent
                let score = colour.saturationComponent * (1 - abs(brightness - 0.62))
                if best == nil || score > best!.score { best = (score, colour) }
            }
        }

        guard let best, best.colour.saturationComponent > 0.12 else { return nil }
        return Color(hue: Double(best.colour.hueComponent),
                     saturation: Double(min(0.92, max(0.55, best.colour.saturationComponent * 1.3))),
                     brightness: Double(min(1, max(0.74, best.colour.brightnessComponent * 1.3))))
    }

    private static func average(of image: CIImage, in rect: CGRect) -> NSColor? {
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: rect),
        ]), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                       blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }

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
