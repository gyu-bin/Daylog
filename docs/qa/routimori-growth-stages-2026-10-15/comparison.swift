import AppKit
import ImageIO
import UniformTypeIdentifiers

// Art review only; source files are never edited. No total-height normalization.
// swift comparison.swift <registration.json> <new-output-directory>
// Registration coordinates are source pixels, measured from the top-left.
// Example schema (replace every measurement with actual approved registration):
// {"referenceSpan":1536,"referenceBodyWidth":700,"stages":[
//   {"stage":1,"file":"assets/stage1.png","bodyWidth":700,"feetX":768,"feetY":1350}, ... ]}
// If all images share the same master canvas/body scale, use identical bodyWidth values.
// Otherwise bodyWidth must measure the SAME torso landmarks in all four images, never
// overall alpha bounds, leaf span, or total character height. Files resolve beside JSON.
struct Registration: Decodable {
    let referenceSpan: Double
    let referenceBodyWidth: Double
    let stages: [Entry]
    struct Entry: Decodable {
        let stage: Int
        let file: String
        let bodyWidth: Double
        let feetX: Double
        let feetY: Double
    }
}
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: comparison.swift <registration.json> <new-output-directory>")
}
let registrationURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let config = try JSONDecoder().decode(Registration.self, from: Data(contentsOf: registrationURL))
precondition(config.referenceSpan.isFinite && config.referenceSpan > 0)
precondition(config.referenceBodyWidth.isFinite && config.referenceBodyWidth > 0)
precondition(config.stages.count == 4 && Set(config.stages.map(\.stage)) == Set(1...4), "Exactly stages1–4 required")
let fm = FileManager.default
if fm.fileExists(atPath: output.path), !(try fm.contentsOfDirectory(atPath: output.path)).isEmpty {
    fatalError("Refusing nonempty output directory: \(output.path)")
}
struct RegisteredImage {
    let entry: Registration.Entry
    let image: CGImage
}
let images = config.stages.sorted { $0.stage < $1.stage }.map { entry -> RegisteredImage in
    let url = registrationURL.deletingLastPathComponent().appendingPathComponent(entry.file)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot read \(url.path)") }
    precondition(entry.bodyWidth.isFinite && entry.bodyWidth > 0 && entry.bodyWidth <= Double(image.width))
    precondition(entry.feetX.isFinite && entry.feetY.isFinite && entry.feetX >= 0 && entry.feetX <= Double(image.width))
    precondition(entry.feetY >= 0 && entry.feetY <= Double(image.height))
    return RegisteredImage(entry: entry, image: image)
}
try fm.createDirectory(at: output, withIntermediateDirectories: true)
let rgb = CGColorSpace(name: CGColorSpace.sRGB)!
for size: CGFloat in [64, 220] {
    // Each source gets a uniform affine scale based ONLY on the measured torso width.
    let scales = images.map { size / CGFloat(config.referenceSpan) * CGFloat(config.referenceBodyWidth / $0.entry.bodyWidth) }
    let left = ceil(zip(images, scales).map { CGFloat($0.0.entry.feetX) * $0.1 }.max()!)
    let right = ceil(zip(images, scales).map { (CGFloat($0.0.image.width) - CGFloat($0.0.entry.feetX)) * $0.1 }.max()!)
    let above = ceil(zip(images, scales).map { CGFloat($0.0.entry.feetY) * $0.1 }.max()!)
    let below = ceil(zip(images, scales).map { (CGFloat($0.0.image.height) - CGFloat($0.0.entry.feetY)) * $0.1 }.max()!)
    // Reserve full source canvases, so taller leaves are never cropped by board layout.
    let tileWidth = max(80, left + right), tileHeight = above + below
    let margin: CGFloat = 20, gap: CGFloat = 24, header: CGFloat = 70
    let width = margin * 2 + tileWidth * 4 + gap * 3
    let height = margin * 2 + tileHeight + header
    for displayScale: CGFloat in [1, 3] {
        for mode in ["light", "dark"] {
            let ctx = CGContext(data: nil, width: Int(ceil(width * displayScale)), height: Int(ceil(height * displayScale)),
                                bitsPerComponent: 8, bytesPerRow: 0, space: rgb,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.scaleBy(x: displayScale, y: displayScale)
            let bg = mode == "light" ? NSColor(srgbRed: 0.97, green: 0.96, blue: 0.94, alpha: 1)
                                     : NSColor(srgbRed: 0.13, green: 0.145, blue: 0.17, alpha: 1)
            ctx.setFillColor(bg.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.interpolationQuality = .high
            for (index, item) in images.enumerated() {
                let k = scales[index]
                let footX = margin + CGFloat(index) * (tileWidth + gap) + (tileWidth - left - right) / 2 + left
                let footY = margin + below
                ctx.draw(item.image, in: CGRect(x: footX - CGFloat(item.entry.feetX) * k,
                                               y: footY - (CGFloat(item.image.height) - CGFloat(item.entry.feetY)) * k,
                                               width: CGFloat(item.image.width) * k, height: CGFloat(item.image.height) * k))
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12),
                                                       .foregroundColor: mode == "light" ? NSColor.black : NSColor.white]
            ("\(Int(size))pt reference span · @\(Int(displayScale))x · same body scale" as NSString)
                .draw(at: CGPoint(x: margin, y: height - 25), withAttributes: attrs)
            for index in 0..<4 {
                ("Stage \(index + 1)" as NSString).draw(at: CGPoint(x: margin + CGFloat(index) * (tileWidth + gap),
                                                                       y: margin + tileHeight + 14), withAttributes: attrs)
            }
            NSGraphicsContext.restoreGraphicsState()
            let url = output.appendingPathComponent("comparison-\(Int(size))pt-\(mode)-\(Int(displayScale))x.png")
            let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
            precondition(CGImageDestinationFinalize(dest))
        }
    }
    print("\(Int(size))pt: all four body widths = \(size * CGFloat(config.referenceBodyWidth / config.referenceSpan))pt; feet share one baseline.")
}
print("Wrote8 boards to \(output.path). No automatic anatomy detection or artwork changes.")
