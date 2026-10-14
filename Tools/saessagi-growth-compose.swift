// 새싹이 성장 단계 그림을 공식 새싹이(saessagi_idle)로 만든다. 몸·얼굴·발은 공식 그림 그대로이고 머리 위의 잎만 단계마다 다르다.
//
//   xcrun swift Tools/saessagi-growth-compose.swift
//
// 읽는 것: Daylog/Assets.xcassets/Saessagi/saessagi_idle(_leaf).imageset (공식 새싹이와 그 잎 레이어)
//          Tools/saessagi-growth-art/saessagi_growth_flower_v1.png (받은 성장 그림. 꽃잎만 떼어 쓴다)
// 쓰는 것(Daylog/Assets.xcassets/Saessagi, 모두 공식 그림과 같은 1024 캔버스·같은 자리):
//   saessagi_growth_leaf_layer   2단계 잎: 공식 두 잎 + 가운데에서 솟은 셋째 잎
//   saessagi_growth_flower_layer 3단계 잎: 공식 두 잎 + 조금 낮은 셋째 잎 + 그 끝에 핀 작은 꽃
//   saessagi_growth_sprout / _leaf / _flower  단계별 한 장 그림(움직임 줄이기와 그림을 만들지 못했을 때 쓴다)
//
// 셋째 잎은 공식 오른쪽 잎을 떼어 줄이고 세운 것이다. 줄이면 외곽선이 얇아지므로 공식 외곽선 색(#321105)으로 바깥을 다시 두껍게 한다.
// 꽃은 받은 성장 그림의 꽃잎만 쓰고(잎과 줄기는 쓰지 않는다), 외곽선을 공식 갈색으로 바꾼다.
// 끝에 단계별 그림이 차지하는 범위를 출력한다. 앱의 `SaessagiPose.growthContent`가 그 합이다.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("Daylog/Assets.xcassets/Saessagi")
let side = 1024
let brown: (UInt8, UInt8, UInt8) = (50, 17, 5)

/// 1024 RGBA(알파를 곱하지 않은 값), 위에서 아래로.
struct Image {
    var px: [UInt8]

    init() { px = [UInt8](repeating: 0, count: side * side * 4) }

    init(_ url: URL) {
        guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: url)) ?? Data()), rep.pixelsWide == side, rep.pixelsHigh == side
        else { fatalError("그림을 읽을 수 없습니다: \(url.lastPathComponent) (저장소 루트에서 실행하세요)") }
        px = [UInt8](repeating: 0, count: side * side * 4)
        var p = [Int](repeating: 0, count: 4)
        for y in 0..<side { for x in 0..<side {
            rep.getPixel(&p, atX: x, y: y)
            for c in 0..<4 { px[(y * side + x) * 4 + c] = UInt8(p[c]) }
        } }
    }

    func alpha(_ x: Int, _ y: Int) -> Int { (x < 0 || y < 0 || x >= side || y >= side) ? 0 : Int(px[(y * side + x) * 4 + 3]) }

    var cgImage: CGImage {
        var pre = px
        for i in stride(from: 0, to: pre.count, by: 4) {
            let a = Int(pre[i + 3])
            for c in 0..<3 { pre[i + c] = UInt8(Int(pre[i + c]) * a / 255) }
        }
        let context = CGContext(data: &pre, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    /// 불투명에 가까운 픽셀의 범위.
    var bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int) {
        var b = (side, side, -1, -1)
        for y in 0..<side { for x in 0..<side where alpha(x, y) > 128 { b = (min(b.0, x), min(b.1, y), max(b.2, x), max(b.3, y)) } }
        return b
    }

    func save(_ name: String) {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied, bytesPerRow: side * 4, bitsPerPixel: 32
        )!
        var clean = px
        // 투명한 자리는 색도 지운다(파일이 작아진다).
        for i in stride(from: 0, to: clean.count, by: 4) where clean[i + 3] == 0 { clean[i] = 0; clean[i + 1] = 0; clean[i + 2] = 0 }
        clean.withUnsafeBytes { memcpy(rep.bitmapData!, $0.baseAddress!, clean.count) }
        let set = folder.appendingPathComponent("\(name).imageset")
        try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
        try! rep.retagging(with: .sRGB)!.representation(using: .png, properties: [:])!.write(to: set.appendingPathComponent("\(name).png"))
        try! """
        {
          "images": [
            {
              "filename": "\(name).png",
              "idiom": "universal"
            }
          ],
          "info": {
            "author": "xcode",
            "version": 1
          }
        }

        """.write(to: set.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    }
}

/// `source`의 `from`을 `to`로 옮기며 `scale`배로 줄이고 `degrees`만큼 돌린다(시계 방향이 양수).
func place(_ source: Image, from: CGPoint, to: CGPoint, scale: Double, degrees: Double = 0) -> Image {
    var buffer = [UInt8](repeating: 0, count: side * side * 4)
    let context = CGContext(data: &buffer, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    // CoreGraphics는 아래가 원점이다. 위에서 아래 좌표로 계산하도록 뒤집는다.
    context.translateBy(x: 0, y: CGFloat(side)); context.scaleBy(x: 1, y: -1)
    context.translateBy(x: to.x, y: to.y); context.rotate(by: degrees * .pi / 180); context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -from.x, y: -from.y)
    context.translateBy(x: 0, y: CGFloat(side)); context.scaleBy(x: 1, y: -1)
    context.draw(source.cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
    var out = Image()
    for i in stride(from: 0, to: buffer.count, by: 4) {
        let a = Int(buffer[i + 3])
        out.px[i + 3] = buffer[i + 3]
        if a > 0 { for c in 0..<3 { out.px[i + c] = UInt8(min(255, Int(buffer[i + c]) * 255 / a)) } }
    }
    return out
}

/// 바깥 외곽선을 `distance`픽셀 두껍게: 모양을 넓히고 새로 덮인 자리를 공식 외곽선 색으로 칠한다.
func thicken(_ image: Image, by distance: Int) -> Image {
    var out = image
    guard distance > 0 else { return out }
    for y in 0..<side { for x in 0..<side where image.alpha(x, y) < 250 {
        var best = 0
        for dy in -distance...distance { for dx in -distance...distance where dx * dx + dy * dy <= distance * distance {
            best = max(best, image.alpha(x + dx, y + dy))
        } }
        let own = image.alpha(x, y)
        guard best > own else { continue }
        let i = (y * side + x) * 4
        // 원래의 반투명 가장자리는 외곽선 색 위에 섞는다.
        for (c, value) in [brown.0, brown.1, brown.2].enumerated() {
            out.px[i + c] = UInt8((Int(image.px[i + c]) * own + Int(value) * (255 - own)) / 255)
        }
        out.px[i + 3] = UInt8(best)
    } }
    return out
}

/// `top`을 `bottom` 위에 겹친다.
func over(_ top: Image, _ bottom: Image) -> Image {
    var out = Image()
    for i in stride(from: 0, to: out.px.count, by: 4) {
        let ta = Double(top.px[i + 3]) / 255, ba = Double(bottom.px[i + 3]) / 255, oa = ta + ba * (1 - ta)
        out.px[i + 3] = UInt8((oa * 255).rounded())
        guard oa > 0 else { continue }
        for c in 0..<3 { out.px[i + c] = UInt8(((Double(top.px[i + c]) * ta + Double(bottom.px[i + c]) * ba * (1 - ta)) / oa).rounded()) }
    }
    return out
}

let officialLeaf = Image(folder.appendingPathComponent("saessagi_idle_leaf.imageset/saessagi_idle_leaf.png"))
let official = Image(folder.appendingPathComponent("saessagi_idle.imageset/saessagi_idle.png"))

// 셋째 잎: 공식 오른쪽 잎(줄기 쪽은 뺀다). 밑동을 기준으로 줄이고 왼쪽으로 기울여 세운다.
var lobe = officialLeaf
for y in 0..<side { for x in 0..<side where x < 540 || y > 262 { lobe.px[(y * side + x) * 4 + 3] = 0 } }
let lobeBase = CGPoint(x: 548, y: 236)
let tilt = -62.0
let outline = 18.0   // 공식 잎 외곽선의 두께(픽셀)
func thirdLeaf(scale: Double, baseY: Double) -> Image {
    thicken(place(lobe, from: lobeBase, to: CGPoint(x: 512, y: baseY), scale: scale, degrees: tilt),
            by: Int((outline * (1 - scale)).rounded()))
}

// 2단계: 두 잎 사이 가운데에서 솟은 셋째 잎(앞쪽).
let leafStage = over(thirdLeaf(scale: 0.56, baseY: 287 - 72), officialLeaf)

// 3단계: 셋째 잎을 조금 낮추고 작게 해서, 그 끝에 꽃이 핀 모습.
let budLeaf = thirdLeaf(scale: 0.56 * 0.85, baseY: 287 - 72 * 0.6)
let flowerSource = Image(root.appendingPathComponent("Tools/saessagi-growth-art/saessagi_growth_flower_v1.png"))
var flower = Image()
let flowerCenter = CGPoint(x: 515, y: 210)
for y in 0..<side { for x in 0..<side {
    let dx = Double(x) - flowerCenter.x, dy = Double(y) - flowerCenter.y
    guard dx * dx + dy * dy < 175 * 175 else { continue }
    let i = (y * side + x) * 4
    let r = Int(flowerSource.px[i]), g = Int(flowerSource.px[i + 1]), b = Int(flowerSource.px[i + 2]), a = Int(flowerSource.px[i + 3])
    // 꽃잎(분홍)·꽃술(노랑)·꽃잎 외곽선(자주)만. 초록 잎과 줄기는 쓰지 않는다.
    guard a > 0, r >= g + 8 || (r > 200 && g > 150) else { continue }
    if (r * 3 + g * 6 + b) / 10 < 110 {
        flower.px[i] = brown.0; flower.px[i + 1] = brown.1; flower.px[i + 2] = brown.2
    } else {
        for c in 0..<3 { flower.px[i + c] = flowerSource.px[i + c] }
    }
    flower.px[i + 3] = UInt8(a)
} }
let budBounds = budLeaf.bounds
var tip = CGPoint(x: 512, y: budBounds.minY)
search: for y in 0..<side { for x in 0..<side where budLeaf.alpha(x, y) > 200 { tip = CGPoint(x: x, y: y); break search } }
let flowerStage = over(place(flower, from: flowerCenter, to: CGPoint(x: tip.x, y: tip.y + 26), scale: 0.45), over(budLeaf, officialLeaf))

leafStage.save("saessagi_growth_leaf_layer")
flowerStage.save("saessagi_growth_flower_layer")
// 한 장 그림: 공식 그림 위에 단계의 잎을 겹친다(공식 잎과 같은 자리라 그대로 덮인다).
official.save("saessagi_growth_sprout")
over(leafStage, official).save("saessagi_growth_leaf")
over(flowerStage, official).save("saessagi_growth_flower")

for (name, image) in [("sprout", official), ("leaf", over(leafStage, official)), ("flower", over(flowerStage, official))] {
    let b = image.bounds
    print("\(name): x \(b.minX)-\(b.maxX) y \(b.minY)-\(b.maxY)")
}
