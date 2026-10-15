import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Register a complete generated component on the master canvas. No painting,
// reconstruction, mirroring, or upscaling: only transparent-margin removal,
// uniform downsampling and translation. Coordinates are top-left pixels.
let args = CommandLine.arguments
guard args.count == 6 else { fatalError("register-part source.png output.png x y width") }
let sourceURL = URL(fileURLWithPath: args[1])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Invalid input") }
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
let scan = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                     bytesPerRow: image.width * 4, space: space, bitmapInfo: bitmap)!
scan.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
let bytes = scan.data!.assumingMemoryBound(to: UInt8.self)
var minX = image.width, maxX = -1, minY = image.height, maxY = -1
var opaque = 0, partial = 0
var histogram = [Int](repeating: 0, count: 256)
for y in 0..<image.height { for x in 0..<image.width {
    let alpha = bytes[(y * image.width + x) * 4 + 3]
    histogram[Int(alpha)] += 1
    if alpha > 8 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
        if alpha == 255 { opaque += 1 } else { partial += 1 }
    }
} }
guard maxX >= minX else { fatalError("Empty component") }
let bounds = CGRect(x: minX, y: minY, width: maxX-minX+1, height: maxY-minY+1)
let x = Double(args[3])!, y = Double(args[4])!, width = Double(args[5])!
guard width <= bounds.width else { fatalError("Upscaling is prohibited") }
let height = bounds.height * width / bounds.width
guard x >= 0, y >= 0, x+width <= 1536, y+height <= 1536 else { fatalError("Component exceeds canvas") }
let canvas = CGContext(data: nil, width: 1536, height: 1536, bitsPerComponent: 8,
                       bytesPerRow: 1536*4, space: space, bitmapInfo: bitmap)!
canvas.interpolationQuality = .high
canvas.draw(image.cropping(to: bounds)!, in: CGRect(x: x, y: 1536-y-height, width: width, height: height))
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, canvas.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("PNG write failed") }
print("source=\(image.width)x\(image.height) alphaBounds=\(bounds) opaque=\(opaque) partial=\(partial) registered=(\(x),\(y),\(width),\(height))")
print("alphaHistogram=\(histogram.enumerated().sorted { $0.element > $1.element }.prefix(12).map { "\($0.offset):\($0.element)" })")
