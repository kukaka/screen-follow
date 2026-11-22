import CoreGraphics
import Foundation
import ImageIO

let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ rgb: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(rgb >> 16) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255, alpha: 1)
}

func drawIcon(pixels: Int, to url: URL) {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                            bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    let tile = CGPath(roundedRect: CGRect(x: 89, y: 89, width: 846, height: 846),
                      cornerWidth: 186, cornerHeight: 186, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -15), blur: 26,
                      color: CGColor(gray: 0, alpha: 0.22))
    context.addPath(tile)
    context.setFillColor(color(0x13264F))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(tile)
    context.clip()
    let gradient = CGGradient(colorsSpace: space,
                              colors: [color(0x146866), color(0x17234F)] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 180, y: 900),
                               end: CGPoint(x: 825, y: 170), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()

    func screen(_ rect: CGRect, fill: UInt32, stroke: UInt32) {
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 43, cornerHeight: 43, transform: nil))
        context.setFillColor(color(fill))
        context.setStrokeColor(color(stroke))
        context.setLineWidth(45)
        context.drawPath(using: .fillStroke)
    }

    screen(CGRect(x: 430, y: 441, width: 315, height: 235), fill: 0x1D4A64, stroke: 0x77E2D2)
    screen(CGRect(x: 278, y: 348, width: 320, height: 231), fill: 0x203959, stroke: 0xF2FBFF)
    context.setStrokeColor(color(0xF2FBFF))
    context.setLineWidth(37)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 438, y: 344))
    context.addLine(to: CGPoint(x: 438, y: 288))
    context.move(to: CGPoint(x: 369, y: 288))
    context.addLine(to: CGPoint(x: 507, y: 288))
    context.strokePath()

    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
}

for size in [16, 32, 128, 256, 512] {
    drawIcon(pixels: size, to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    drawIcon(pixels: size * 2, to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
