// 새싹이 기본(idle) 그림을 대기 애니메이션용 레이어 셋으로 나눈다. 그림을 새로 그리지 않고 원본 픽셀을 그대로 나눠 담는다.
//
//   xcrun swift Tools/saessagi-layers.swift
//
// 읽는 것: Daylog/Assets.xcassets/Saessagi/saessagi_idle.imageset/saessagi_idle.png (1024×1024)
// 쓰는 것(같은 폴더의 imageset, 모두 원본과 같은 크기·같은 자리):
//   saessagi_idle_leaf  잎사귀와 그 아래 이음매(줄기가 머리로 들어가기 전까지)
//   saessagi_idle_eyes  두 눈
//   saessagi_idle_body  나머지(잎을 뺀 몸. 눈 자리는 둘레의 살색으로 메운다)
// 셋을 겹치면 원본과 같다(끝에 차이를 재서 알려 준다). 앱은 잎을 줄기 밑동에서 살짝 돌리고, 눈을 세로로 접어 깜빡인다.
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

// 2. 눈: 타원 안.
func eyeWeight(_ x: Int, _ y: Int, margin: CGFloat) -> Bool {
    Geometry.eyes.contains { rect in
        let rx = rect.width / 2 + margin, ry = rect.height / 2 + margin
        let dx = (CGFloat(x) + 0.5 - rect.midX) / rx, dy = (CGFloat(y) + 0.5 - rect.midY) / ry
        return dx * dx + dy * dy <= 1
    }
}

var leaf = [UInt8](repeating: 0, count: w * h * 4)
var eyes = [UInt8](repeating: 0, count: w * h * 4)
var body = original
var hole = [Bool](repeating: false, count: w * h)
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        if leafMask[y * w + x] {
            for c in 0..<4 { leaf[i + c] = original[i + c]; body[i + c] = 0 }
        } else if eyeWeight(x, y, margin: Geometry.eyeMargin) {
            for c in 0..<4 { eyes[i + c] = original[i + c] }
            hole[y * w + x] = true
        }
    }
}

// 3. 몸의 눈 자리를 둘레의 색으로 메운다. 먼저 가장자리부터 안쪽으로 이웃의 평균을 채워 넣고,
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
write(body, name: "saessagi_idle_body")

// 확인: 몸 위에 눈과 잎을 겹치면 원본과 같아야 한다(눈 레이어는 불투명한 눈이 메운 자리를 그대로 덮는다).
var worst = 0, different = 0
for i in 0..<(w * h) {
    let base = i * 4
    for c in 0..<4 {
        let eyeAlpha = Int(eyes[base + 3])
        let under = Int(body[base + c]) * (255 - eyeAlpha) / 255
        let composed = min(255, Int(leaf[base + c]) + Int(eyes[base + c]) + (leaf[base + 3] > 0 ? 0 : under))
        let gap = abs(composed - Int(original[base + c]))
        worst = max(worst, gap)
        if gap > 2 { different += 1 }
    }
}
let leafCount = leafMask.filter { $0 }.count, eyeCount = hole.filter { $0 }.count
print("잎 \(leafCount)픽셀, 눈 \(eyeCount)픽셀. 겹쳤을 때 원본과의 최대 차이 \(worst) (2를 넘는 값 \(different)개)")
