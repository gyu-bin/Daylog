// 휴가 화면의 해먹(새싹이가 누운 그림)을 움직일 수 있게 나눠 에셋으로 만든다.
//
//   xcrun swift Tools/vacation-hammock-layers.swift
//
// 읽는 것: Tools/vacation-art/hammock/vacation_pose_{relax,sip,adjust}.png (받은 1024 투명 PNG. 세 장은 손 언저리만 다르다)
// 쓰는 것: Daylog/Assets.xcassets/Vacation/<이름>.imageset
//   vacation_hammock_base   쉬는 그림에서 머리 위 잎을 뺀 것(잎 뒤에 가려 있던 베개 자리는 둘레 색으로 메운다)
//   vacation_hammock_leaf   머리 위 잎(줄기 밑동을 중심으로 흔들린다)
//   vacation_hammock_sip    마시는 그림에서 쉬는 그림과 다른 자리만 잘라 낸 것(위에 겹쳐 서서히 나타낸다)
//   vacation_hammock_adjust 선글라스를 고쳐 쓰는 그림의 같은 부분
// 그림을 새로 그리지 않는다. 끝에 레이어마다 1024 캔버스에서의 자리를 출력한다(앱의 `VacationArt`에 적는다).
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let art = root.appendingPathComponent("Tools/vacation-art/hammock")
let catalog = root.appendingPathComponent("Daylog/Assets.xcassets/Vacation")
let side = 1024

/// 비트맵(위에서 아래로, RGBA, 알파를 곱하지 않은 값).
struct Bitmap {
    var pixels: [UInt8]
    subscript(x: Int, y: Int, c: Int) -> UInt8 {
        get { pixels[(y * side + x) * 4 + c] }
        set { pixels[(y * side + x) * 4 + c] = newValue }
    }

    init(_ name: String) {
        guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: art.appendingPathComponent(name))) ?? Data()),
              rep.pixelsWide == side, rep.pixelsHigh == side else { fatalError("원본을 읽을 수 없습니다: \(name) (저장소 루트에서 실행하세요)") }
        pixels = [UInt8](repeating: 0, count: side * side * 4)
        var value = [Int](repeating: 0, count: 4)
        for y in 0..<side { for x in 0..<side {
            rep.getPixel(&value, atX: x, y: y)
            for c in 0..<4 { pixels[(y * side + x) * 4 + c] = UInt8(value[c]) }
        } }
    }

    func isLeafGreen(_ x: Int, _ y: Int) -> Bool {
        let r = Int(self[x, y, 0]), g = Int(self[x, y, 1]), b = Int(self[x, y, 2])
        return self[x, y, 3] > 200 && g > r + 40 && g > b + 30
    }

    /// `rect` 자리만 잘라 imageset으로 저장한다.
    func save(_ name: String, rect: CGRect) {
        let width = Int(rect.width), height = Int(rect.height)
        var data = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            for c in 0..<4 { data[(y * width + x) * 4 + c] = self[Int(rect.minX) + x, Int(rect.minY) + y, c] }
        } }
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied, bytesPerRow: width * 4, bitsPerPixel: 32
        )!
        data.withUnsafeBytes { memcpy(rep.bitmapData!, $0.baseAddress!, data.count) }
        let folder = catalog.appendingPathComponent("\(name).imageset")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // 원본과 같은 sRGB로 적는다(장치 색으로 두면 앱에서 색이 조금 달라진다).
        try! rep.retagging(with: .sRGB)!.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(name).png"))
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

        """.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
        print("\(name): x \(Int(rect.minX)) y \(Int(rect.minY)) w \(width) h \(height)")
    }
}

/// 알파가 있는 픽셀을 감싸는 자리(가장자리에 `margin`만큼 여유, 짝수로 맞춤).
func bounds(_ bitmap: Bitmap, where include: (Int, Int) -> Bool, margin: Int = 4) -> CGRect {
    var minX = side, minY = side, maxX = -1, maxY = -1
    for y in 0..<side { for x in 0..<side where bitmap[x, y, 3] > 0 && include(x, y) {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    } }
    precondition(maxX >= 0, "빈 레이어")
    let left = max(0, (minX - margin) & ~1), top = max(0, (minY - margin) & ~1)
    let right = min(side, (maxX + margin + 2) & ~1), bottom = min(side, (maxY + margin + 2) & ~1)
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
}

let relax = Bitmap("vacation_pose_relax.png"), sip = Bitmap("vacation_pose_sip.png"), adjust = Bitmap("vacation_pose_adjust.png")

// 1. 머리 위 잎: 진한 초록을 씨앗으로, 연두·밝은 반사광(초록 기운이 있는 색)과 그 둘레 16픽셀 안의 어두운 외곽선·반투명 가장자리를 모은 뒤,
//    잎 안쪽에 갇힌 구멍(반사광 등)을 메운다.
var green = [Bool](repeating: false, count: side * side)
var leafBox = (minX: side, minY: side, maxX: 0, maxY: 0)
for y in 0..<side { for x in 0..<side where relax.isLeafGreen(x, y) {
    green[y * side + x] = true
    leafBox = (min(leafBox.minX, x), min(leafBox.minY, y), max(leafBox.maxX, x), max(leafBox.maxY, y))
} }
let reach = 16
let box = (minX: max(0, leafBox.minX - reach - 2), minY: max(0, leafBox.minY - reach - 2),
           maxX: min(side - 1, leafBox.maxX + reach + 2), maxY: min(side - 1, leafBox.maxY + reach + 2))
func nearGreen(_ x: Int, _ y: Int) -> Bool {
    for dy in -reach...reach { for dx in -reach...reach where dx * dx + dy * dy <= reach * reach {
        let nx = x + dx, ny = y + dy
        if nx >= 0, ny >= 0, nx < side, ny < side, green[ny * side + nx] { return true }
    } }
    return false
}
var leafMask = [Bool](repeating: false, count: side * side)
for y in box.minY...box.maxY { for x in box.minX...box.maxX where relax[x, y, 3] > 0 {
    let r = Int(relax[x, y, 0]), g = Int(relax[x, y, 1]), b = Int(relax[x, y, 2])
    let greenish = g >= r - 5 && g > b + 15
    let luma = (r * 3 + g * 6 + b) / 10
    if greenish || ((luma < 75 || relax[x, y, 3] < 250) && nearGreen(x, y)) { leafMask[y * side + x] = true }
} }
// 상자 가장자리에서 잎이 아닌 픽셀을 따라 번져 닿지 않는 곳은 잎 안쪽이다.
var outside = [Bool](repeating: false, count: side * side)
var stack: [(Int, Int)] = []
for x in box.minX...box.maxX { stack.append((x, box.minY)); stack.append((x, box.maxY)) }
for y in box.minY...box.maxY { stack.append((box.minX, y)); stack.append((box.maxX, y)) }
while let (x, y) = stack.popLast() {
    let i = y * side + x
    guard x >= box.minX, x <= box.maxX, y >= box.minY, y <= box.maxY, !outside[i], !leafMask[i] else { continue }
    outside[i] = true
    stack.append((x + 1, y)); stack.append((x - 1, y)); stack.append((x, y + 1)); stack.append((x, y - 1))
}
for y in box.minY...box.maxY { for x in box.minX...box.maxX where !outside[y * side + x] && relax[x, y, 3] > 0 {
    leafMask[y * side + x] = true
} }
var leaf = relax
var base = relax
for i in 0..<(side * side) {
    if leafMask[i] { for c in 0..<4 { base.pixels[i * 4 + c] = 0 } } else { leaf.pixels[i * 4 + 3] = 0 }
}
// 잎이 가리던 자리 가운데 뒤에 그림(베개·천)이 있던 곳은 둘레의 색으로 메운다. 잎이 흔들릴 때 드러나는 틈이 비지 않게 한다.
// 바깥(투명)과 닿은 곳은 투명하게 남는다: 둘레 픽셀의 평균을 안쪽으로 번지게 하는 단순한 메우기다.
var hole = leafMask
for _ in 0..<200 {
    var next = hole
    var filled = 0
    for y in 1..<(side - 1) { for x in 1..<(side - 1) where hole[y * side + x] {
        var sum = [0, 0, 0, 0], count = 0
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where !hole[(y + dy) * side + x + dx] {
            let a = Int(base[x + dx, y + dy, 3])
            for c in 0..<3 { sum[c] += Int(base[x + dx, y + dy, c]) * a }
            sum[3] += a
            count += 1
        }
        guard count > 0 else { continue }
        let alpha = sum[3] / count
        for c in 0..<3 { base[x, y, c] = UInt8(sum[3] > 0 ? sum[c] / sum[3] : 0) }
        base[x, y, 3] = UInt8(alpha)
        next[y * side + x] = false
        filled += 1
    } }
    hole = next
    if filled == 0 { break }
}
// 메운 자리 가운데 둘레가 대부분 투명했던 곳(잎 위쪽의 하늘)은 지우고, 나머지(베개·천)는 불투명하게 둔다.
for i in 0..<(side * side) where leafMask[i] { base.pixels[i * 4 + 3] = base.pixels[i * 4 + 3] < 110 ? 0 : 255 }

// 2. 마시기·고쳐 쓰기: 쉬는 그림과 다른 자리.
func changed(_ other: Bitmap) -> CGRect {
    bounds(other, where: { x, y in
        (0..<4).contains { abs(Int(other[x, y, $0]) - Int(relax[x, y, $0])) > 24 }
    }, margin: 10)
}
let sipRect = changed(sip), adjustRect = changed(adjust)
let leafRect = bounds(leaf, where: { _, _ in true })
// 겹쳐 놓는 그림에는 잎을 넣지 않는다(잎은 따로 흔들리므로, 들어가면 멈춘 잎이 하나 더 보인다).
var sipLayer = sip, adjustLayer = adjust
var overlap = 0
for i in 0..<(side * side) where leafMask[i] {
    sipLayer.pixels[i * 4 + 3] = 0
    adjustLayer.pixels[i * 4 + 3] = 0
    let x = i % side, y = i / side
    if sipRect.contains(CGPoint(x: x, y: y)) || adjustRect.contains(CGPoint(x: x, y: y)) { overlap += 1 }
}
precondition(overlap < 400, "손이 바뀌는 자리가 잎과 너무 많이 겹칩니다: \(overlap)")

base.save("vacation_hammock_base", rect: bounds(base, where: { _, _ in true }))
leaf.save("vacation_hammock_leaf", rect: leafRect)
sipLayer.save("vacation_hammock_sip", rect: sipRect)
adjustLayer.save("vacation_hammock_adjust", rect: adjustRect)
print("잎과 겹쳐 빼낸 픽셀: \(overlap)")
print("잎 초록 범위: x \(leafBox.minX)-\(leafBox.maxX) y \(leafBox.minY)-\(leafBox.maxY)")
