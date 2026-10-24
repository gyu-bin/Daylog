// Diagnostic only: reads original source images, never modifies them.
// Run from the repository root with: swift -module-cache-path /tmp/pio-art-qa-swift <this file>
import AppKit
import ImageIO
import CryptoKit

let outfits: [(String, String)] = [
    ("cherryBlossom", "벚꽃 피오"), ("summerVacation", "여름 휴가 피오"), ("autumn", "가을 피오"),
    ("winter", "겨울 피오"), ("halloween", "할로윈 피오"), ("christmas", "크리스마스 피오"),
    ("hanbok", "한복 피오"), ("cafe", "카페 피오"), ("student", "학생 피오"),
    ("fitness", "운동 피오"), ("rainyDay", "비 오는 날 피오"), ("pajamas", "잠옷 피오"),
    ("astronaut", "우주인 피오")
]
let directory = URL(fileURLWithPath: "docs/qa/pio-outfit-phase2-2026-10-16")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var images: [String: CGImage] = [:]
var assets: [[String: Any]] = []
for (id, title) in outfits {
    let path = "Daylog/PioWardrobe.xcassets/pio_outfit_\(id).imageset/pio_outfit_\(id).png"
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    images[id] = image
    let w = image.width, h = image.height
    let rgba = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    rgba.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let pixels = rgba.data!.assumingMemoryBound(to: UInt8.self)
    var bounds = [w, h, -1, -1], zero = 0, partial = 0, edgeCount = 0, edgeMax = 0
    for y in 0..<h {
        for x in 0..<w {
            let alpha = Int(pixels[(y * w + x) * 4 + 3])
            if alpha == 0 { zero += 1 }
            if alpha > 0 && alpha < 255 { partial += 1 }
            if alpha > 16 {
                bounds[0] = min(bounds[0], x); bounds[1] = min(bounds[1], y)
                bounds[2] = max(bounds[2], x); bounds[3] = max(bounds[3], y)
                if x == 0 || y == 0 || x == w - 1 || y == h - 1 { edgeCount += 1 }
            }
            if x == 0 || y == 0 || x == w - 1 || y == h - 1 { edgeMax = max(edgeMax, alpha) }
        }
    }
    assets.append([
        "id": id, "title": title, "path": path, "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
        "bytes": data.count, "width": w, "height": h, "imageCount": CGImageSourceGetCount(source),
        "sourceAlphaInfo": image.alphaInfo.rawValue, "zeroAlphaPixels": zero, "partialAlphaPixels": partial,
        "boundsAlphaGreaterThan16": bounds, "significantAlphaEdgePixels": edgeCount, "maximumEdgeAlpha": edgeMax,
        "layerStructure": "single flattened RGBA image; no independent body/eyes/wings/accessory source layers",
        "sampling": "full canvas aspectFit; no trim, recolor, mask repair, or upscaling"
    ])
}
var outputs: [[String: Any]] = []
for points in [48, 64, 120, 220] {
    for dark in [false, true] {
        for density in [1, 2] {
            let cellWidth = max(158, points + 40), cellHeight = points + 62
            let width = cellWidth * 4 + 32, height = cellHeight * 4 + 90
            let context = CGContext(data: nil, width: width * density, height: height * density,
                                    bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.scaleBy(x: CGFloat(density), y: CGFloat(density))
            let background = dark ? NSColor(srgbRed: 0.07, green: 0.12, blue: 0.10, alpha: 1)
                                  : NSColor(srgbRed: 0.98, green: 0.97, blue: 0.93, alpha: 1)
            let ink = dark ? NSColor(srgbRed: 0.92, green: 0.95, blue: 0.86, alpha: 1)
                           : NSColor(srgbRed: 0.18, green: 0.29, blue: 0.20, alpha: 1)
            context.setFillColor(background.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            func text(_ value: String, _ rect: CGRect, size: CGFloat, bold: Bool = false, center: Bool = false) {
                let paragraph = NSMutableParagraphStyle(); paragraph.alignment = center ? .center : .left
                (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular), .foregroundColor: ink, .paragraphStyle: paragraph])
            }
            let theme = dark ? "dark" : "light"
            text("피오 의상 · \(points)pt · \(theme) · @\(density)x", CGRect(x: 20, y: height - 38, width: width - 40, height: 26), size: 19, bold: true)
            text("원본 전체 캔버스 맞춤 · 정적 표시 QA · 레이어/리깅 검증 아님", CGRect(x: 20, y: height - 60, width: width - 40, height: 19), size: 11)
            var cells: [[String: Any]] = []
            for (i, outfit) in outfits.enumerated() {
                let left = 16 + (i % 4) * cellWidth
                let top = height - 74 - (i / 4) * cellHeight
                let box = CGRect(x: left + (cellWidth - points) / 2, y: top - points, width: points, height: points)
                let image = images[outfit.0]!
                let scale = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
                let drawing = CGRect(x: box.midX - CGFloat(image.width) * scale / 2,
                                     y: box.midY - CGFloat(image.height) * scale / 2,
                                     width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
                context.interpolationQuality = .high
                context.draw(image, in: drawing)
                text(outfit.1, CGRect(x: left, y: top - points - 29, width: cellWidth, height: 22), size: 14, bold: true, center: true)
                cells.append(["id": outfit.0, "canvasBoundsPointsBottomLeft": [Double(drawing.minX), Double(drawing.minY), Double(drawing.width), Double(drawing.height)]])
            }
            NSGraphicsContext.restoreGraphicsState()
            let file = "artwork-\(points)pt-\(theme)-\(density)x.png"
            let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
            try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(file))
            outputs.append(["file": file, "sizePoints": points, "pixelsPerPoint": density, "theme": theme,
                            "widthPixels": width * density, "heightPixels": height * density, "cells": cells])
        }
    }
}
let manifest: [String: Any] = [
    "scope": "13 approved full-resolution static costume assets, 48/64/120/220pt, ivory/forest, 1x and 2x",
    "renderer": "CoreGraphics premultiplied-alpha source-over; AppKit labels; high interpolation; no source asset writes",
    "assets": assets, "contactSheets": outputs,
    "limitation": "Offline static size/compositing diagnostic, not app screenshots, animation, four-stage compatibility, or GPU performance validation"
]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: directory.appendingPathComponent("artwork-size-manifest.json"))
print("Rendered \(outputs.count) contact sheets; inspected metadata for \(assets.count) original assets.")
