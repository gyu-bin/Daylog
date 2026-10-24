import AppKit
import ImageIO
import UniformTypeIdentifiers

// Composes existing pixel tiles at 1:1; no artwork resizing or modification.
// compare-crest <before-rendered/complete> <after-rendered/complete> <new-output-directory>
guard CommandLine.arguments.count == 4 else { fatalError("Expected before, after and output directories") }
let before = URL(fileURLWithPath: CommandLine.arguments[1])
let after = URL(fileURLWithPath: CommandLine.arguments[2])
let output = URL(fileURLWithPath: CommandLine.arguments[3])
let fm = FileManager.default
if fm.fileExists(atPath: output.path), !(try fm.contentsOfDirectory(atPath: output.path)).isEmpty {
    fatalError("Refusing nonempty comparison destination: \(output.path)")
}
try fm.createDirectory(at: output, withIntermediateDirectories: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func read(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Missing image: \(url.path)") }
    return image
}
func compose(mode: String, pose: String, size: Int?, scale: Int) {
    func name(stage: Int) -> String {
        if let size { return "tiles/\(mode)-stage\(stage)-\(pose)-\(size)pt-\(scale)x.png" }
        return "native/\(mode)-stage\(stage)-\(pose).png"
    }
    let tiles = [read(before.appendingPathComponent(name(stage: 3))),
                 read(before.appendingPathComponent(name(stage: 4))),
                 read(after.appendingPathComponent(name(stage: 4)))]
    let factor = size == nil ? 2 : scale
    let margin = 16 * factor, gap = 24 * factor, header = 68 * factor
    let tileWidth = tiles.map(\.width).max()!, tileHeight = tiles.map(\.height).max()!
    let width = margin * 2 + tileWidth * 3 + gap * 2, height = margin * 2 + tileHeight + header
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let background = mode == "light" ? NSColor(srgbRed: 0.97, green: 0.96, blue: 0.94, alpha: 1)
                                     : NSColor(srgbRed: 0.13, green: 0.145, blue: 0.17, alpha: 1)
    ctx.setFillColor(background.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.interpolationQuality = .none
    for (index, tile) in tiles.enumerated() {
        let x = margin + index * (tileWidth + gap) + (tileWidth - tile.width) / 2
        ctx.draw(tile, in: CGRect(x: x, y: margin, width: tile.width, height: tile.height))
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let ink: NSColor = mode == "light" ? .black : .white
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: CGFloat(12 * factor)), .foregroundColor: ink]
    let resolution = size.map { "\($0)pt @\(scale)x" } ?? "Native 1536px · full composite"
    ("\(resolution) · \(pose) · \(mode)" as NSString).draw(at: CGPoint(x: margin, y: height - 24 * factor), withAttributes: attrs)
    for (index, title) in ["Stage 3", "Stage 4 before", "Stage 4 after"].enumerated() {
        (title as NSString).draw(at: CGPoint(x: margin + index * (tileWidth + gap), y: margin + tileHeight + 14 * factor), withAttributes: attrs)
    }
    NSGraphicsContext.restoreGraphicsState()
    let prefix = size.map { "\($0)pt-\(scale)x" } ?? "native"
    let url = output.appendingPathComponent("\(prefix)-\(mode)-\(pose).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(dest))
}
for mode in ["light", "dark"] {
    for pose in ["neutral", "crest-minus12", "crest-plus12", "jump", "landing"] {
        compose(mode: mode, pose: pose, size: nil, scale: 1)
        for size in [64, 220] {
            for scale in [1, 3] { compose(mode: mode, pose: pose, size: size, scale: scale) }
        }
    }
}
print("Wrote 50 comparison boards to \(output.path)")
