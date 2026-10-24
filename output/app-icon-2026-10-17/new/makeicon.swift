import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// usage: makeicon <source.png> <outdir>
// The source is a rounded-square icon drawn on a white page. Produces:
//  - ios_1024.png: full-bleed, opaque (iOS applies its own mask). Pixels outside the drawn rounded square
//    (and its thin rim) are refilled from the neighbouring art so no white shows inside the iOS mask.
//  - mac_1024.png: macOS-style tile (824pt body at 100,100 on a transparent 1024 canvas, soft shadow).
let a = CommandLine.arguments
let out = URL(fileURLWithPath: a[2])
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let src = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!, 0, nil)!
let SW = src.width, SH = src.height
var sp = [UInt8](repeating: 0, count: SW * SH * 4)
CGContext(data: &sp, width: SW, height: SH, bitsPerComponent: 8, bytesPerRow: SW * 4, space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.draw(src, in: CGRect(x: 0, y: 0, width: SW, height: SH))
func lum(_ p: [UInt8], _ w: Int, _ x: Int, _ y: Int) -> Int { let o = (y * w + x) * 4; return (Int(p[o]) * 3 + Int(p[o + 1]) * 6 + Int(p[o + 2])) / 10 }
// Bounding box from the straight middle edges (first pixel clearly darker than the white page).
let midY = SH / 2, midX = SW / 2
var left = 0; while left < SW / 2 && lum(sp, SW, left, midY) > 244 { left += 1 }
var right = SW - 1; while right > SW / 2 && lum(sp, SW, right, midY) > 244 { right -= 1 }
var top = 0; while top < SH / 2 && lum(sp, SW, midX, top) > 244 { top += 1 }
var bottom = SH - 1; while bottom > SH / 2 && lum(sp, SW, midX, bottom) > 244 { bottom -= 1 }
// Corner radius from the 45° inset of the top-left corner.
var inset = 0; while inset < 400 && lum(sp, SW, left + inset, top + inset) > 244 { inset += 1 }
let radius = Double(inset) / (1 - 1 / 2.0.squareRoot())
print("bbox x[\(left),\(right)] y[\(top),\(bottom)] size \(right - left + 1)x\(bottom - top + 1) cornerInset \(inset) radius≈\(Int(radius))")

// 1. Crop the tile and scale to 1024.
let side = min(right - left + 1, bottom - top + 1)
let N = 1024
let ox = left + (right - left + 1 - side) / 2, oy = top + (bottom - top + 1 - side) / 2
let crop = src.cropping(to: CGRect(x: ox, y: oy, width: side, height: side))!
var px = [UInt8](repeating: 0, count: N * N * 4)
let cx = CGContext(data: &px, width: N, height: N, bitsPerComponent: 8, bytesPerRow: N * 4, space: space,
                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
cx.interpolationQuality = .high
cx.draw(crop, in: CGRect(x: 0, y: 0, width: N, height: N))
let s = Double(N) / Double(side), r = radius * s
// 2. Outside = the white page, found by flood fill from the four corners over near-white, low-saturation pixels.
//    The tile is everything else, eroded by 10px to drop its thin bevel rim. Outside pixels are refilled from
//    the nearest tile pixel (multi-source BFS) and then smoothed, so nothing white shows inside the iOS mask.
func isPage(_ i: Int) -> Bool {
    let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), b = Int(px[i * 4 + 2])
    return min(r, g, b) >= 236 && max(r, g, b) - min(r, g, b) <= 10
}
var page = [Bool](repeating: false, count: N * N)
var stack = [0, N - 1, (N - 1) * N, N * N - 1].filter { isPage($0) }
for i in stack { page[i] = true }
while let i = stack.popLast() { let x = i % N, y = i / N
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] { let xx = x + dx, yy = y + dy
        guard xx >= 0, xx < N, yy >= 0, yy < N else { continue }
        let j = yy * N + xx; if !page[j] && isPage(j) { page[j] = true; stack.append(j) } } }
// also treat the rim band as outside: any pixel within 10px of the page
var dist = [Int](repeating: Int.max, count: N * N)
var queue: [Int] = []; for i in 0..<(N * N) where page[i] { dist[i] = 0; queue.append(i) }
var head = 0
while head < queue.count { let i = queue[head]; head += 1; let x = i % N, y = i / N
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] { let xx = x + dx, yy = y + dy
        guard xx >= 0, xx < N, yy >= 0, yy < N else { continue }
        let j = yy * N + xx; if dist[j] == Int.max { dist[j] = dist[i] + 1; queue.append(j) } } }
let erode = 18
var known = [Bool](repeating: false, count: N * N)
var col = [[Double]](repeating: [0, 0, 0], count: N * N)
var holes: [Int] = []
var q2: [Int] = []
for i in 0..<(N * N) {
    if dist[i] > erode { known[i] = true; col[i] = [Double(px[i * 4]), Double(px[i * 4 + 1]), Double(px[i * 4 + 2])]; q2.append(i) }
    else { holes.append(i) }
}
print("page px \(page.filter { $0 }.count), refilled px \(holes.count)")
// nearest-known colour by BFS outward from the tile
var filled = known; head = 0
var nearest = [Int](repeating: -1, count: N * N); for i in q2 { nearest[i] = i }
while head < q2.count { let i = q2[head]; head += 1; let x = i % N, y = i / N
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] { let xx = x + dx, yy = y + dy
        guard xx >= 0, xx < N, yy >= 0, yy < N else { continue }
        let j = yy * N + xx; if !filled[j] { filled[j] = true; nearest[j] = nearest[i]; col[j] = col[i]; q2.append(j) } } }
// Mirror the tile's own texture across its edge: sample at 2b - p (b = nearest tile pixel), falling back to b.
for i in holes { let b = nearest[i]; guard b >= 0 else { continue }
    let x = i % N, y = i / N, bx = b % N, by = b / N
    let mx = 2 * bx - x, my = 2 * by - y
    if mx >= 0, mx < N, my >= 0, my < N, known[my * N + mx] { col[i] = col[my * N + mx] }
}
for _ in 0..<3 { for i in holes { let x = i % N, y = i / N
    var acc = [0.0, 0.0, 0.0], c = 0.0
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] { let xx = x + dx, yy = y + dy
        guard xx >= 0, xx < N, yy >= 0, yy < N else { continue }
        let j = yy * N + xx; for k in 0..<3 { acc[k] += col[j][k] }; c += 1 }
    col[i] = acc.map { $0 / c }
} }
var ios = [UInt8](repeating: 255, count: N * N * 4)
for i in 0..<(N * N) { for k in 0..<3 { ios[i * 4 + k] = UInt8(max(0, min(255, col[i][k].rounded()))) }; ios[i * 4 + 3] = 255 }
func save(_ img: CGImage, _ name: String) {
    let d = CGImageDestinationCreateWithURL(out.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
// Opaque RGB (no alpha channel) for the iOS marketing icon.
let iosCtx = CGContext(data: &ios, width: N, height: N, bitsPerComponent: 8, bytesPerRow: N * 4, space: space,
                       bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let iosImg = iosCtx.makeImage()!
save(iosImg, "ios_1024.png")

// 3. macOS tile: 824 body at (100,100), corner radius 185 (Apple grid), soft shadow, transparent outside.
let mac = CGContext(data: nil, width: N, height: N, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
mac.interpolationQuality = .high
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let path = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
mac.saveGState()
mac.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.32))
mac.addPath(path); mac.setFillColor(CGColor(gray: 1, alpha: 1)); mac.fillPath()
mac.restoreGState()
mac.saveGState(); mac.addPath(path); mac.clip()
mac.draw(iosImg, in: body)
mac.restoreGState()
save(mac.makeImage()!, "mac_1024.png")
print("ok")
