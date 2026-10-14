// 새싹이 성장 단계 그림(새싹·잎사귀·꽃)을 애니메이션용 레이어로 나눈다. 그림을 새로 그리지 않고 원본 픽셀을 나눠 담는다.
//
//   xcrun swift Tools/saessagi-growth-layers.swift
//
// 읽는 것: Daylog/Assets.xcassets/Saessagi/saessagi_growth_<단계>.imageset (받은 1024 투명 PNG, 단계마다 몸의 자리가 같다)
// 쓰는 것(같은 폴더, 모두 원본과 같은 크기·같은 자리):
//   saessagi_growth_<단계>_leaf  머리 위의 잎(꽃 단계는 꽃과 잎). 줄기 밑동을 중심으로 흔든다
//   saessagi_growth_<단계>_eyes  두 눈(눈동자와 반사광). 세로로 접어 깜빡인다
//   saessagi_growth_<단계>_body  나머지. 눈 자리는 둘레의 살색으로 메우고, 잎 자리는 비워 둔다
// 끝에 단계마다 잎이 도는 중심과 눈의 중심을 출력한다. 그 값이 앱의 `SaessagiLayerSet`에 적혀 있다.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("Daylog/Assets.xcassets/Saessagi")
let side = 1024

struct Bitmap {
    var pixels: [UInt8]
    subscript(x: Int, y: Int, c: Int) -> UInt8 {
        get { pixels[(y * side + x) * 4 + c] }
        set { pixels[(y * side + x) * 4 + c] = newValue }
    }
    func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int, Int) {
        (Int(self[x, y, 0]), Int(self[x, y, 1]), Int(self[x, y, 2]), Int(self[x, y, 3]))
    }

    init(_ url: URL) {
        guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: url)) ?? Data()), rep.pixelsWide == side, rep.pixelsHigh == side
        else { fatalError("원본을 읽을 수 없습니다: \(url.lastPathComponent) (저장소 루트에서 실행하세요)") }
        pixels = [UInt8](repeating: 0, count: side * side * 4)
        var value = [Int](repeating: 0, count: 4)
        for y in 0..<side { for x in 0..<side {
            rep.getPixel(&value, atX: x, y: y)
            for c in 0..<4 { pixels[(y * side + x) * 4 + c] = UInt8(value[c]) }
        } }
    }

    func save(_ name: String) {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied, bytesPerRow: side * 4, bitsPerPixel: 32
        )!
        pixels.withUnsafeBytes { memcpy(rep.bitmapData!, $0.baseAddress!, pixels.count) }
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

typealias Mask = [Bool]

/// 상자 안에서 `mask`에 갇힌 구멍(상자 가장자리에서 번져 닿지 않는 곳)을 채운다.
func fillEnclosed(_ mask: inout Mask, image: Bitmap, box: (Int, Int, Int, Int)) {
    let (x0, y0, x1, y1) = box
    var outside = Mask(repeating: false, count: side * side)
    var stack: [(Int, Int)] = []
    for x in x0...x1 { stack.append((x, y0)); stack.append((x, y1)) }
    for y in y0...y1 { stack.append((x0, y)); stack.append((x1, y)) }
    while let (x, y) = stack.popLast() {
        let i = y * side + x
        guard x >= x0, x <= x1, y >= y0, y <= y1, !outside[i], !mask[i] else { continue }
        outside[i] = true
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    }
    for y in y0...y1 { for x in x0...x1 where !outside[y * side + x] && image[x, y, 3] > 0 { mask[y * side + x] = true } }
}

/// `seed` 둘레 `reach` 픽셀 안의 어두운 외곽선·반투명 가장자리를 함께 담는다.
func grow(_ seed: Mask, image: Bitmap, reach: Int, box: (Int, Int, Int, Int), darkLuma: Int = 80) -> Mask {
    var mask = seed
    let (x0, y0, x1, y1) = box
    for y in y0...y1 { for x in x0...x1 where !seed[y * side + x] && image[x, y, 3] > 0 {
        let (r, g, b, a) = image.rgb(x, y)
        guard (r * 3 + g * 6 + b) / 10 < darkLuma || a < 250 else { continue }
        var near = false
        search: for dy in -reach...reach { for dx in -reach...reach where dx * dx + dy * dy <= reach * reach {
            let nx = x + dx, ny = y + dy
            if nx >= 0, ny >= 0, nx < side, ny < side, seed[ny * side + nx] { near = true; break search }
        } }
        if near { mask[y * side + x] = true }
    } }
    return mask
}

/// 지운 눈 자리를 둘레(살색) 픽셀의 평균 색으로 메운다. 얼굴은 거의 한 색이라 평평하게 칠해도 눈에 띄지 않는다
/// (눈 레이어가 늘 덮고 있고, 깜빡이는 0.2초만 드러난다).
func fillFace(_ image: inout Bitmap, hole: Mask) {
    var sum = [0, 0, 0], count = 0
    let points = (0..<(side * side)).filter { hole[$0] }
    let x0 = max(10, points.map { $0 % side }.min()! - 10), x1 = min(side - 11, points.map { $0 % side }.max()! + 10)
    let y0 = max(10, points.map { $0 / side }.min()! - 10), y1 = min(side - 11, points.map { $0 / side }.max()! + 10)
    var alpha = 0
    for y in y0...y1 { for x in x0...x1 where !hole[y * side + x] && image[x, y, 3] > 240 {
        var near = false
        search: for dy in -8...8 { for dx in -8...8 where hole[(y + dy) * side + x + dx] { near = true; break search } }
        guard near else { continue }
        let (r, g, b, _) = image.rgb(x, y)
        guard (r * 3 + g * 6 + b) / 10 > 200 else { continue }
        sum[0] += r; sum[1] += g; sum[2] += b
        alpha += Int(image[x, y, 3])
        count += 1
    } }
    precondition(count > 0, "눈 둘레의 살색을 찾지 못했습니다")
    for i in 0..<(side * side) where hole[i] {
        for c in 0..<3 { image.pixels[i * 4 + c] = UInt8(sum[c] / count) }
        image.pixels[i * 4 + 3] = UInt8(alpha / count)
    }
}

for stage in ["sprout", "leaf", "flower"] {
    let name = "saessagi_growth_\(stage)"
    let source = Bitmap(folder.appendingPathComponent("\(name).imageset/\(name).png"))

    // 1. 머리 위: 초록(잎), 분홍(꽃잎), 노랑(꽃술)을 씨앗으로. 볼의 분홍과 섞이지 않게 머리 위쪽에서만 찾는다.
    var seed = Mask(repeating: false, count: side * side)
    var box = (side, side, 0, 0)
    for y in 0..<520 { for x in 0..<side {
        let (r, g, b, a) = source.rgb(x, y)
        guard a > 200 else { continue }
        let green = g > r + 25 && g > b + 20
        let pink = r > g + 40 && r > b + 5 && r > 150
        let yellow = r > 200 && g > 150 && b < 130
        guard green || pink || yellow else { continue }
        seed[y * side + x] = true
        box = (min(box.0, x), min(box.1, y), max(box.2, x), max(box.3, y))
    } }
    let reach = 14
    let leafBox = (max(0, box.0 - reach - 2), max(0, box.1 - reach - 2), min(side - 1, box.2 + reach + 2), min(side - 1, box.3 + reach + 2))
    // 꽃잎의 외곽선은 짙은 자주색이라 조금 밝아도 외곽선으로 본다.
    var leafMask = grow(seed, image: source, reach: reach, box: leafBox, darkLuma: 125)
    fillEnclosed(&leafMask, image: source, box: leafBox)
    // 줄기 밑동: 잎 가운데 가장 아래의 초록 픽셀들.
    var stemY = 0
    for y in 0..<520 { for x in 400..<624 where seed[y * side + x] { stemY = max(stemY, y) } }
    let stemXs = (400..<624).filter { seed[stemY * side + $0] }
    let stemX = stemXs.reduce(0, +) / max(stemXs.count, 1)

    // 2. 눈: 얼굴 한가운데 높이의 어두운 덩어리 둘(입보다 위, 좌우 대칭). 안쪽의 반사광까지 담는다.
    var dark = Mask(repeating: false, count: side * side)
    for y in 540..<680 { for x in 300..<724 {
        let (r, g, b, a) = source.rgb(x, y)
        if a > 200 && (r * 3 + g * 6 + b) / 10 < 70 { dark[y * side + x] = true }
    } }
    // 덩어리 나누기.
    var label = [Int](repeating: 0, count: side * side)
    var blobs: [(id: Int, count: Int, minX: Int, minY: Int, maxX: Int, maxY: Int)] = []
    for y in 540..<680 { for x in 300..<724 where dark[y * side + x] && label[y * side + x] == 0 {
        let id = blobs.count + 1
        var stack = [(x, y)], info = (id: id, count: 0, minX: x, minY: y, maxX: x, maxY: y)
        while let (cx, cy) = stack.popLast() {
            let i = cy * side + cx
            guard cx >= 300, cx < 724, cy >= 540, cy < 680, dark[i], label[i] == 0 else { continue }
            label[i] = id
            info.count += 1
            info.minX = min(info.minX, cx); info.maxX = max(info.maxX, cx); info.minY = min(info.minY, cy); info.maxY = max(info.maxY, cy)
            stack += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
        }
        blobs.append(info)
    } }
    // 눈은 둥글고 큰 덩어리 둘: 너비와 높이가 비슷하고, 가장 큰 두 개.
    let eyes = blobs.filter { b in
        let w = b.maxX - b.minX + 1, h = b.maxY - b.minY + 1
        return b.count > 400 && Double(h) / Double(w) > 0.9 && Double(h) / Double(w) < 2.0
    }.sorted { $0.count > $1.count }.prefix(2).sorted { $0.minX < $1.minX }
    precondition(eyes.count == 2, "\(stage): 눈을 찾지 못했습니다 \(blobs.map { ($0.count, $0.minX, $0.minY, $0.maxX, $0.maxY) })")
    var eyeMask = Mask(repeating: false, count: side * side)
    for eye in eyes {
        let margin = 5
        let ebox = (eye.minX - margin, eye.minY - margin, eye.maxX + margin, eye.maxY + margin)
        var m = Mask(repeating: false, count: side * side)
        for y in eye.minY...eye.maxY { for x in eye.minX...eye.maxX where label[y * side + x] == eye.id { m[y * side + x] = true } }
        fillEnclosed(&m, image: source, box: ebox)
        // 가장자리의 번진 픽셀(살색과 섞인 회색)까지.
        for y in ebox.1...ebox.3 { for x in ebox.0...ebox.2 where !m[y * side + x] {
            let (r, g, b, _) = source.rgb(x, y)
            guard (r * 3 + g * 6 + b) / 10 < 200 else { continue }
            if [(1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)].contains(where: { m[(y + $0.1) * side + x + $0.0] }) {
                eyeMask[y * side + x] = true
            }
        } }
        for i in 0..<(side * side) where m[i] { eyeMask[i] = true }
    }
    let eyeCenterX = Double(eyes[0].minX + eyes[1].maxX) / 2
    let eyeCenterY = Double(eyes.map { $0.minY + $0.maxY }.reduce(0, +)) / 4

    // 줄기 밑동보다 위는 모두 잎 쪽이다(머리는 그 아래에서 시작한다). 잎 둘레의 옅은 가장자리가 몸에 남지 않게 한다.
    for y in 0..<max(stemY - 8, 0) { for x in 0..<side where source[x, y, 3] > 0 { leafMask[y * side + x] = true } }
    var leaf = source, eyesLayer = source, body = source
    for i in 0..<(side * side) {
        // 투명한 자리는 색도 지운다(파일이 작아진다).
        if !leafMask[i] { for c in 0..<4 { leaf.pixels[i * 4 + c] = 0 } }
        if !eyeMask[i] { for c in 0..<4 { eyesLayer.pixels[i * 4 + c] = 0 } }
        if leafMask[i] || eyeMask[i] { for c in 0..<4 { body.pixels[i * 4 + c] = 0 } }
    }
    // 눈 자리는 살색으로 메운다. 잎 자리는 비워 둔다: 뒤가 하늘이고, 머리에 닿는 줄기 밑동은 잎 레이어가 늘 덮는다(도는 중심이라 거의 움직이지 않는다).
    fillFace(&body, hole: eyeMask)
    leaf.save("\(name)_leaf")
    eyesLayer.save("\(name)_eyes")
    body.save("\(name)_body")
    print("\(stage): leafPivot (\(stemX), \(stemY)) eyeCenter (\(eyeCenterX), \(eyeCenterY)) eyes \(eyes.map { "\($0.minX)-\($0.maxX)x\($0.minY)-\($0.maxY)" })")
}
