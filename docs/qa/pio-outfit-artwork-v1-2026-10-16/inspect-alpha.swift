import Foundation
import ImageIO
import CoreGraphics
var results: [[String: Any]] = []
for path in CommandLine.arguments.dropFirst() {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot decode: \(path)") }
    let w = image.width, h = image.height
    let data = UnsafeMutablePointer<UInt8>.allocate(capacity: w*h*4)
    data.initialize(repeating: 0, count: w*h*4)
    let context = CGContext(data: data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var zero = 0, partial = 0, edge = 0, significantEdge = 0, maxEdgeAlpha = 0, opaque = 0
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h { for x in 0..<w {
        let a = Int(data[(y*w+x)*4+3])
        if a == 0 { zero += 1 } else if a < 255 { partial += 1 } else { opaque += 1 }
        if x == 0 || y == 0 || x == w-1 || y == h-1 { maxEdgeAlpha = max(maxEdgeAlpha,a); if a > 0 { edge += 1 }; if a > 16 { significantEdge += 1 } }
        if a > 16 { minX = min(minX,x); minY = min(minY,y); maxX = max(maxX,x); maxY = max(maxY,y) }
    } }
    results.append(["path":path,"width":w,"height":h,"zeroAlphaPixels":zero,"partialAlphaPixels":partial,
        "opaquePixels":opaque,"nonzeroAlphaEdgePixels":edge,"visibleBounds":[minX,minY,maxX+1,maxY+1], "significantAlphaEdgePixels":significantEdge, "maxEdgeAlpha":maxEdgeAlpha, "visibleAlphaThreshold":16,
        "passesTransparencyAndPadding":zero>0 && opaque>0 && significantEdge==0 && minX>0 && minY>0 && maxX<w-1 && maxY<h-1])
    data.deallocate()
}
let output = try! JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted,.sortedKeys])
print(String(data: output,encoding:.utf8)!)
