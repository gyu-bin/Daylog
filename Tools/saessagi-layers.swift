// 새싹이 기본(idle) 그림을 대기·걷기 애니메이션용 레이어로 나눈다. 그림을 새로 그리지 않고 원본 픽셀을 그대로 나눠 담는다.
//
//   xcrun swift Tools/saessagi-layers.swift
//
// 읽는 것: Daylog/Assets.xcassets/Saessagi/saessagi_idle.imageset/saessagi_idle.png (1024×1024)
// 쓰는 것(같은 폴더의 imageset, 모두 원본과 같은 크기·같은 자리):
//   saessagi_idle_leaf        잎사귀와 그 아래 이음매(줄기가 머리로 들어가기 전까지)
//   saessagi_idle_eyes        두 눈(눈만. 둘레의 살색은 담지 않는다)
//   saessagi_idle_mouth       입
//   saessagi_idle_foot_left   왼발: 몸통 아래쪽의 왼쪽 절반(몸통과 겹치는 윗부분 포함)
//   saessagi_idle_foot_right  오른발
//   saessagi_idle_body        나머지(잎과 발을 뺀 몸. 눈과 입 자리는 둘레의 살색으로 메운다)
// 발 → 몸 → 입·눈 → 잎 순서로 겹치면 원본과 거의 같다(끝에 차이를 재서 알려 준다).
// 앱은 잎을 줄기 밑동에서 돌리고, 눈을 세로로 접어 깜빡이고, 걸을 때 발을 번갈아 들고 눈과 입을 가는 쪽으로 옮긴다.
//
// 자르는 자리(`Geometry`)는 지금 원본에 맞춘 값이다. idle 그림을 바꾸면 값을 다시 재고, 앱의 `SaessagiIdleLayers`도 같이 고친다.
import AppKit

enum Geometry {
    /// 잎과 머리를 가르는 가로선(이 행부터 아래는 몸). 줄기 둘레에서만 가른다: 그 밖에서는 잎과 머리 사이가 비어 있다.
    static let neckY = 288
    static let neckX = 470...560
    /// 잎 덩어리 안의 한 점(왼쪽 잎 가운데).
    static let leafSeed = (x: 300, y: 150)
    /// 두 눈(어두운 타원)이 차지하는 자리.
    static let eyes = [CGRect(x: 335, y: 520, width: 80, height: 99), CGRect(x: 604, y: 521, width: 80, height: 98)]
    /// 눈을 지울 때 가장자리의 번진 픽셀까지 덮으려고 넓히는 폭.
    static let eyeMargin: CGFloat = 9
    /// 입(어두운 선)이 차지하는 자리.
    static let mouth = CGRect(x: 468, y: 587, width: 83, height: 25)
    static let mouthMargin: CGFloat = 8
    /// 몸통과 발을 가르는 가로선: 이 행부터 아래가 발이다(다리 사이의 아치보다 위).
    static let footY = 870
    /// 발 레이어가 그 선 위로 더 담는 높이. 걸을 때 몸이 들썩여도 발과 몸 사이가 비지 않는다.
    static let footOverlap = 60
    /// 왼발과 오른발을 가르는 세로선.
    static let footSplitX = 512
    /// 다리 사이(아치와 그 위)는 몸에 남긴다. 발이 좌우로 벌어져도 가운데가 비지 않는다.
    static let crotchX = 430...594
    static let crotchBottomY = 918
    /// 발 레이어의 겹치는 부분에서는 외곽선을 빼고 안쪽 살색만 담는다(몸이 기울 때 선이 두 겹으로 보이지 않게).
    static let overlapInset = 30
    /// 다만 가로선 바로 위의 이만큼은 외곽선까지 담는다. 몸이 기울어 옆구리가 들릴 때 선이 끊겨 보이지 않는다.
    static let overlapOutline = 22
    /// 눈·입의 선 색(가장자리의 반투명 픽셀을 이 색으로 담는다. 살색이 묻어 나오지 않게).
    static let ink: (r: Double, g: Double, b: Double) = (58, 34, 26)
    /// 메운 자리를 다듬는 횟수.
    static let smoothingPasses = 600
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("Daylog/Assets.xcassets/Saessagi")
let sourceURL = catalog.appendingPathComponent("saessagi_idle.imageset/saessagi_idle.png")
guard let data = try? Data(contentsOf: sourceURL), let source = NSBitmapImageRep(data: data)?.cgImage else {
    fatalError("원본을 읽을 수 없습니다: \(sourceURL.path) (저장소 루트에서 실행하세요)")
}
let w = source.width, h = source.height
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGImageAlphaInfo.premultipliedLast.rawValue

/// 위에서 아래로 읽는 RGBA(미리 곱한 알파) 픽셀.
func pixels(of image: CGImage) -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: w * h * 4)
    let context = CGContext(data: &buffer, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buffer
}

func write(_ buffer: [UInt8], name: String) {
    var copy = buffer
    let context = CGContext(data: &copy, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)!
    let folder = catalog.appendingPathComponent("\(name).imageset")
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    try! png.write(to: folder.appendingPathComponent("\(name).png"))
    let contents = """
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

    """
    try! contents.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

let original = pixels(of: source)
func alpha(_ x: Int, _ y: Int) -> Int { Int(original[(y * w + x) * 4 + 3]) }

// 1. 잎: 줄기 둘레를 가로선으로 막고, 잎 안의 한 점에서 이어진 픽셀을 모은다.
var isLeaf = [Bool](repeating: false, count: w * h)
func isBarrier(_ x: Int, _ y: Int) -> Bool { y == Geometry.neckY && Geometry.neckX.contains(x) }
var stack = [(Geometry.leafSeed.x, Geometry.leafSeed.y)]
isLeaf[Geometry.leafSeed.y * w + Geometry.leafSeed.x] = true
while let (x, y) = stack.popLast() {
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        let nx = x + dx, ny = y + dy
        guard nx >= 0, ny >= 0, nx < w, ny < h, !isLeaf[ny * w + nx], alpha(nx, ny) > 40, !isBarrier(nx, ny) else { continue }
        isLeaf[ny * w + nx] = true
        stack.append((nx, ny))
    }
}
// 가장자리의 옅은 픽셀(알파가 낮아 위에서 빠진 것)은 가까운 쪽에 붙인다: 잎에서 몇 픽셀 안이고 몸의 진한 픽셀이 아니면 잎.
var leafMask = isLeaf
for _ in 0..<6 {
    var grown = leafMask
    for y in 1..<(h - 1) {
        for x in 1..<(w - 1) where !leafMask[y * w + x] && alpha(x, y) > 0 && alpha(x, y) <= 40 && y < Geometry.neckY + 12 {
            if leafMask[y * w + x - 1] || leafMask[y * w + x + 1] || leafMask[(y - 1) * w + x] || leafMask[(y + 1) * w + x] {
                grown[y * w + x] = true
            }
        }
    }
    leafMask = grown
}

// 2. 눈과 입. 몸에서는 넉넉한 자리를 지우고(메운다), 레이어에는 선과 눈동자만 담는다.
func inEye(_ x: Int, _ y: Int, margin: CGFloat) -> Bool {
    Geometry.eyes.contains { rect in
        let rx = rect.width / 2 + margin, ry = rect.height / 2 + margin
        let dx = (CGFloat(x) + 0.5 - rect.midX) / rx, dy = (CGFloat(y) + 0.5 - rect.midY) / ry
        return dx * dx + dy * dy <= 1
    }
}
func inMouth(_ x: Int, _ y: Int) -> Bool {
    Geometry.mouth.insetBy(dx: -Geometry.mouthMargin, dy: -Geometry.mouthMargin).contains(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5))
}
/// 그 픽셀이 선 색에 얼마나 가까운가(0 = 살색, 1 = 선). 가장자리의 반투명 정도로 쓴다.
func inkAmount(_ x: Int, _ y: Int) -> Double {
    let i = (y * w + x) * 4
    let a = max(Double(original[i + 3]), 1)
    let luminance = (0.299 * Double(original[i]) + 0.587 * Double(original[i + 1]) + 0.114 * Double(original[i + 2])) * 255 / a
    let amount = (236 - luminance) / (236 - 70)
    return max(0, min(1, (amount - 0.18) / 0.82))
}
func putInk(_ buffer: inout [UInt8], _ i: Int, amount: Double) {
    buffer[i] = UInt8((Geometry.ink.r * amount).rounded())
    buffer[i + 1] = UInt8((Geometry.ink.g * amount).rounded())
    buffer[i + 2] = UInt8((Geometry.ink.b * amount).rounded())
    buffer[i + 3] = UInt8((255 * amount).rounded())
}

/// 행마다 그림이 차지하는 가로 범위.
let rowSpan: [ClosedRange<Int>] = (0..<h).map { y in
    let xs = (0..<w).filter { alpha($0, y) > 128 }
    return (xs.first ?? 0)...(xs.last ?? 0)
}

var leaf = [UInt8](repeating: 0, count: w * h * 4)
var eyes = [UInt8](repeating: 0, count: w * h * 4)
var mouth = [UInt8](repeating: 0, count: w * h * 4)
var footLeft = [UInt8](repeating: 0, count: w * h * 4)
var footRight = [UInt8](repeating: 0, count: w * h * 4)
var body = original
var hole = [Bool](repeating: false, count: w * h)
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        if leafMask[y * w + x] {
            for c in 0..<4 { leaf[i + c] = original[i + c]; body[i + c] = 0 }
            continue
        }
        // 발: 가로선 위로 겹치는 부분까지 담고, 몸에서는 가로선 아래만 지운다.
        if y >= Geometry.footY - Geometry.footOverlap {
            let isOverlap = y < Geometry.footY - Geometry.overlapOutline
            let span = rowSpan[y]
            if isOverlap, x < span.lowerBound + Geometry.overlapInset || x > span.upperBound - Geometry.overlapInset {
                continue
            }
            if x < Geometry.footSplitX {
                for c in 0..<4 { footLeft[i + c] = original[i + c] }
            } else {
                for c in 0..<4 { footRight[i + c] = original[i + c] }
            }
            let isCrotch = Geometry.crotchX.contains(x) && y <= Geometry.crotchBottomY
            if y >= Geometry.footY, !isCrotch { for c in 0..<4 { body[i + c] = 0 } }
            continue
        }
        if inEye(x, y, margin: Geometry.eyeMargin) {
            hole[y * w + x] = true
            if inEye(x, y, margin: -2) {
                // 눈 안쪽(반짝이는 점 포함)은 그대로.
                for c in 0..<4 { eyes[i + c] = original[i + c] }
            } else {
                putInk(&eyes, i, amount: inkAmount(x, y))
            }
        } else if inMouth(x, y) {
            hole[y * w + x] = true
            putInk(&mouth, i, amount: inkAmount(x, y))
        }
    }
}

// 3. 몸의 눈과 입 자리를 둘레의 색으로 메운다. 먼저 가장자리부터 안쪽으로 이웃의 평균을 채워 넣고,
//    그다음 메운 자리만 여러 번 고르게 다듬는다(둘레의 색이 안쪽으로 매끄럽게 이어진다. 줄무늬가 남지 않는다).
var remaining = hole
while remaining.contains(true) {
    var filled: [(Int, [Int])] = []
    for y in 1..<(h - 1) {
        for x in 1..<(w - 1) where remaining[y * w + x] {
            var sum = [0, 0, 0, 0], count = 0
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)] {
                let n = (y + dy) * w + x + dx
                guard !remaining[n] else { continue }
                for c in 0..<4 { sum[c] += Int(body[n * 4 + c]) }
                count += 1
            }
            if count >= 2 { filled.append((y * w + x, sum.map { $0 / count })) }
        }
    }
    guard !filled.isEmpty else { break }
    for (index, color) in filled {
        for c in 0..<4 { body[index * 4 + c] = UInt8(color[c]) }
        remaining[index] = false
    }
}
let holeIndices = hole.indices.filter { hole[$0] }
var smooth = body.map(Double.init)
for _ in 0..<Geometry.smoothingPasses {
    var next = smooth
    for index in holeIndices {
        for c in 0..<4 {
            let i = index * 4 + c
            next[i] = (smooth[i - 4] + smooth[i + 4] + smooth[i - w * 4] + smooth[i + w * 4]) / 4
        }
    }
    smooth = next
}
for index in holeIndices {
    for c in 0..<4 { body[index * 4 + c] = UInt8(max(0, min(255, smooth[index * 4 + c].rounded()))) }
}

write(leaf, name: "saessagi_idle_leaf")
write(eyes, name: "saessagi_idle_eyes")
write(mouth, name: "saessagi_idle_mouth")
write(footLeft, name: "saessagi_idle_foot_left")
write(footRight, name: "saessagi_idle_foot_right")
write(body, name: "saessagi_idle_body")

// 확인: 발 → 몸 → 입 → 눈 → 잎 순서로 겹쳐 원본과 견준다(미리 곱한 알파의 "위에 그리기").
var composed = [Double](repeating: 0, count: w * h * 4)
for layer in [footLeft, footRight, body, mouth, eyes, leaf] {
    for i in 0..<(w * h) {
        let alpha = Double(layer[i * 4 + 3]) / 255
        guard alpha > 0 else { continue }
        for c in 0..<4 { composed[i * 4 + c] = Double(layer[i * 4 + c]) + composed[i * 4 + c] * (1 - alpha) }
    }
}
var worst = 0.0, different = 0
for i in 0..<(w * h * 4) {
    let gap = abs(composed[i] - Double(original[i]))
    worst = max(worst, gap)
    if gap > 12 { different += 1 }
}
let leafCount = leafMask.filter { $0 }.count, holeCount = hole.filter { $0 }.count
print("잎 \(leafCount)픽셀, 눈·입 자리 \(holeCount)픽셀. 겹쳤을 때 원본과의 최대 차이 \(Int(worst)) (12를 넘는 값 \(different)개 / \(w * h * 4))")
