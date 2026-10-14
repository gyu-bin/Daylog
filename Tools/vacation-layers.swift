// 휴가 화면의 야자나무와 배경(하늘·해·구름·별·풍경)을 움직일 수 있게 레이어로 나눠 에셋으로 만든다.
// 해먹과 새싹이는 Tools/vacation-hammock-layers.swift가 만든다.
//
//   xcrun swift Tools/vacation-layers.swift
//
// 읽는 것: Tools/vacation-art/*.svg (받은 벡터 원본: 야자나무 좌우, 배경 낮과 밤)
// 쓰는 것: Daylog/Assets.xcassets/Vacation/<이름>.imageset (투명 PNG, 내용이 있는 자리만 잘라 낸 것)
//
// 그림을 새로 그리지 않는다: 원본의 도형을 묶음별로 골라 따로 그릴 뿐이다. 레이어를 원본의 자리에 겹치면 원본 그림이 된다.
// 끝에 레이어마다 원본 캔버스에서의 자리를 출력한다. 그 값이 앱의 `VacationArt`에 적혀 있다(그림을 바꾸면 함께 고친다).
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let art = root.appendingPathComponent("Tools/vacation-art")
let catalog = root.appendingPathComponent("Daylog/Assets.xcassets/Vacation")

struct Source {
    let header: String
    /// 바깥 묶음을 여는 태그(오른쪽 야자나무는 여기서 좌우를 뒤집는다).
    let group: String
    /// 바깥 묶음 바로 아래의 도형들(그리는 순서대로).
    let children: [String]

    /// `flat`: 바깥 묶음 없이 도형이 바로 놓인 원본(배경).
    init(_ name: String, flat: Bool = false) {
        guard let text = try? String(contentsOf: art.appendingPathComponent(name), encoding: .utf8),
              let defsEnd = text.range(of: "</defs>") else { fatalError("원본을 읽을 수 없습니다: \(name) (저장소 루트에서 실행하세요)") }
        header = String(text[..<defsEnd.upperBound])
        let body = String(text[defsEnd.upperBound...])
        var children: [String] = []
        var group = "<g>"
        var depth = flat ? 1 : 0
        var current = ""
        let tags = try! NSRegularExpression(pattern: "<[^>]+>")
        for match in tags.matches(in: body, range: NSRange(body.startIndex..., in: body)) {
            let tag = String(body[Range(match.range, in: body)!])
            if tag.hasPrefix("</svg") { break }
            let closes = tag.hasPrefix("</"), selfCloses = tag.hasSuffix("/>")
            if depth == 0 {
                // 바깥 묶음을 연다.
                group = tag
                depth = 1
                continue
            }
            if closes {
                depth -= 1
                if depth == 0 { break }
                current += tag
                if depth == 1 { children.append(current); current = "" }
            } else if selfCloses {
                current += tag
                if depth == 1 { children.append(current); current = "" }
            } else {
                current += tag
                depth += 1
            }
        }
        self.children = children
        self.group = group
    }

    func svg(_ indices: [Int], canvas: CGSize) -> String {
        // 캔버스 크기는 머리말의 것을 쓰지 않고 여기서 정한다(야자나무는 아래로 더 그린다).
        var head = header
        if let end = head.range(of: ">") {
            head = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(Int(canvas.width))\" height=\"\(Int(canvas.height))\" "
                + "viewBox=\"0 0 \(Int(canvas.width)) \(Int(canvas.height))\">" + head[end.upperBound...]
        }
        return head + group + indices.map { children[$0] }.joined() + "</g></svg>"
    }
}

/// SVG를 `scale`배로 그려, 내용이 있는 자리만(`crop`을 주면 그 자리만) 잘라 저장한다. 원본 캔버스에서의 자리를 돌려준다.
@discardableResult
func export(_ name: String, svg: String, canvas: CGSize, scale: CGFloat, crop fixed: CGRect? = nil) -> CGRect {
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("daylog-\(name).svg")
    try! svg.write(to: temporary, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: temporary) }
    guard let image = NSImage(contentsOf: temporary) else { fatalError("그릴 수 없습니다: \(name)") }
    let width = Int(canvas.width * scale), height = Int(canvas.height * scale)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()

    // 내용이 있는 범위(위에서 아래로: 비트맵의 첫 줄이 맨 윗줄이다).
    let pixels = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
        for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= 0 else { fatalError("빈 레이어: \(name)") }
    // 가장자리에 여유를 두고, 원본 단위로 딱 떨어지게 맞춘다.
    let step = Int(scale) * 2
    var left = max(0, (minX - step) / step * step), top = max(0, (minY - step) / step * step)
    var right = min(width, (maxX + step * 2) / step * step), bottom = min(height, (maxY + step * 2) / step * step)
    if let fixed {
        left = Int(fixed.minX * scale); top = Int(fixed.minY * scale)
        right = Int(fixed.maxX * scale); bottom = Int(fixed.maxY * scale)
    }
    // 맨 아랫줄 가운데의 색: 풍경 아래로 모래를 이어 칠할 때 쓴다.
    let last = ((bottom - 1) * width + (left + right) / 2) * 4
    lastRowColor = String(format: "%02X%02X%02X", pixels[last], pixels[last + 1], pixels[last + 2])
    let crop = context.makeImage()!.cropping(to: CGRect(x: left, y: top, width: right - left, height: bottom - top))!

    let folder = catalog.appendingPathComponent("\(name).imageset")
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try! NSBitmapImageRep(cgImage: crop).representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(name).png"))
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
    return CGRect(x: CGFloat(left) / scale, y: CGFloat(top) / scale, width: CGFloat(right - left) / scale, height: CGFloat(bottom - top) / scale)
}

var lastRowColor = ""
try! FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: true)
try! "{\n  \"info\": {\n    \"author\": \"xcode\",\n    \"version\": 1\n  }\n}\n"
    .write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

var report: [(String, CGRect)] = []

// 야자나무: 줄기(와 밑동의 풀), 잎, 열매. 원본은 밑동이 캔버스 아래에서 잘려 있어 아래로 더 그린다.
let palm = CGSize(width: 1024, height: 1600)
for side in ["left", "right"] {
    let source = Source("vacation_palm_\(side).svg")
    precondition(source.children.count == 37, "야자나무 원본의 구성이 달라졌습니다")
    report.append(("vacation_palm_\(side)_trunk", export("vacation_palm_\(side)_trunk", svg: source.svg(Array(0...15) + [36], canvas: palm), canvas: palm, scale: 1)))
    report.append(("vacation_palm_\(side)_fronds", export("vacation_palm_\(side)_fronds", svg: source.svg(Array(16...33), canvas: palm), canvas: palm, scale: 1)))
    report.append(("vacation_palm_\(side)_coconuts", export("vacation_palm_\(side)_coconuts", svg: source.svg([34, 35], canvas: palm), canvas: palm, scale: 1)))
}

// 배경: 하늘(세로로 늘여 쓰는 띠), 해·달과 그 빛, 구름 한 덩이(넷이 같은 모양이다), 별, 그리고 산·바다·모래·꽃.
// 하늘과 구름을 풍경에서 떼어 두어야 넓은 창에서도 해와 구름이 화면 안에 남고, 구름이 따로 흐를 수 있다.
let scene = CGSize(width: 2400, height: 2400)
let day = Source("vacation_bg_day.svg", flat: true), night = Source("vacation_bg_night.svg", flat: true)
precondition(day.children.count == 76 && night.children.count == 138, "배경 원본의 구성이 달라졌습니다")
func addScene(_ name: String, _ source: Source, _ indices: [Int], scale: CGFloat = 1, crop: CGRect? = nil) {
    report.append((name, export(name, svg: source.svg(indices, canvas: scene), canvas: scene, scale: scale, crop: crop)))
}
// 하늘은 산 뒤로 가려지는 데까지만 쓴다(원본 1400 높이).
let skyStrip = CGRect(x: 1196, y: 0, width: 8, height: 1400)
addScene("vacation_sky_day", day, [0], crop: skyStrip)
addScene("vacation_sun_day", day, [1, 2])
addScene("vacation_cloud_day", day, [3], scale: 2)
addScene("vacation_scenery_day", day, Array(7...75))
print("vacation_scenery_day 아랫줄 색: #\(lastRowColor)")
addScene("vacation_sky_night", night, [0], crop: skyStrip)
addScene("vacation_stars_night", night, Array(1...62))
addScene("vacation_sun_night", night, [63, 64])
addScene("vacation_cloud_night", night, [65], scale: 2)
addScene("vacation_scenery_night", night, Array(69...137))
print("vacation_scenery_night 아랫줄 색: #\(lastRowColor)")

for (name, rect) in report {
    print("\(name): x \(Int(rect.minX)) y \(Int(rect.minY)) w \(Int(rect.width)) h \(Int(rect.height))")
}
