import AppKit
import ImageIO
import UniformTypeIdentifiers

// Compose approved @3x render tiles without resizing, cropping, or altering artwork.
// Run from the repository root: swift Tools/pio-rig/compare-stage4.swift
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("docs/qa/pio-trial-2026-10-15-stage4/final")
let rgb = CGColorSpace(name: CGColorSpace.sRGB)!

func read(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Cannot read \(url.path)")
    }
    return image
}

for size in [64, 220] {
    for mode in ["light", "dark"] {
        let tiles = (1...4).map { stage in
            read(root.appendingPathComponent("sizes/\(mode)-stage\(stage)-\(size)pt-3x.png"))
        }
        let tileWidth = tiles.map(\.width).max()!
        let tileHeight = tiles.map(\.height).max()!
        let margin = 40, gap = 60
        let width = 2 * margin + 4 * tileWidth + 3 * gap
        let height = tileHeight + 150
        let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: rgb,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Match the unmodified render tile backgrounds.
        let bg: [CGFloat] = mode == "light" ? [0.969, 0.961, 0.941, 1] : [0.129, 0.149, 0.173, 1]
        context.setFillColor(CGColor(colorSpace: rgb, components: bg)!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .none
        for (index, tile) in tiles.enumerated() {
            // Center padding differences; artwork retains its original pixel scale.
            let x = margin + index * (tileWidth + gap) + (tileWidth - tile.width) / 2
            let y = 30 + (tileHeight - tile.height) / 2
            context.draw(tile, in: CGRect(x: x, y: y, width: tile.width, height: tile.height))
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let ink = mode == "light" ? NSColor.black : NSColor.white
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium), .foregroundColor: ink
        ]
        ("Pio growth · \(size)pt · @3x" as NSString).draw(
            at: CGPoint(x: margin, y: height - 44), withAttributes: titleAttributes)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .medium), .foregroundColor: ink
        ]
        for stage in 1...4 {
            let label = "Stage \(stage)" as NSString
            let center = CGFloat(margin + (stage - 1) * (tileWidth + gap)) + CGFloat(tileWidth) / 2
            label.draw(at: CGPoint(x: center - label.size(withAttributes: labelAttributes).width / 2,
                                   y: CGFloat(tileHeight + 64)), withAttributes: labelAttributes)
        }
        NSGraphicsContext.restoreGraphicsState()
        let url = root.appendingPathComponent("comparison-\(size)pt-\(mode).png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination), "Cannot save \(url.path)")
        print(url.path)
    }
}
