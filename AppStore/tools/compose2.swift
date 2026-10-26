// App Store 스크린샷 합성(2026-10-26판: 피오 말풍선·옷장·앱 아이콘·Mac 추가): 실제 시뮬레이터 캡처(AppStore/raw) 위에 배경·문구·기기 테두리를 더해 업로드용 PNG를 만든다.
// 앱 화면은 비율 그대로 줄여서 놓기만 한다(고치거나 다시 그리지 않는다).
//   swift AppStore/tools/compose2.swift           (저장소 루트에서) → AppStore/screenshots-2026-10-26
import AppKit

struct Slide {
    let file: String, raw: String
    let eyebrow: String, headline: String, sub: String
    let accent: (CGFloat, CGFloat, CGFloat)
}

struct Target {
    let name: String, rawDir: String
    let size: CGSize          // 출력 크기(픽셀)
    let base: CGSize          // 배치를 계산하는 기준 크기. 출력은 이 좌표를 그대로 줄이거나 늘린 것
    let isPad: Bool
    let slides: [Slide]
}

let mint: (CGFloat, CGFloat, CGFloat) = (0x43, 0xBF, 0xA6), yellow: (CGFloat, CGFloat, CGFloat) = (0xF4, 0xC6, 0x5E)
let blue: (CGFloat, CGFloat, CGFloat) = (0x63, 0x95, 0xE8), coral: (CGFloat, CGFloat, CGFloat) = (0xEF, 0x8B, 0x80)
let purple: (CGFloat, CGFloat, CGFloat) = (0xA7, 0x8B, 0xFA), orange: (CGFloat, CGFloat, CGFloat) = (0xF5, 0x9E, 0x63)

let phoneSlides = [
    Slide(file: "01-today", raw: "p1-today", eyebrow: "오늘의 루틴", headline: "피오와 함께\n하루를 시작해요", sub: "진행 상황에 맞춰 피오가 한마디 건네요", accent: mint),
    Slide(file: "02-statistics", raw: "p2-stats", eyebrow: "통계", headline: "작은 실천이\n쌓이는 순간", sub: "달성률과 연속 기록으로 변화를 확인하세요", accent: blue),
    Slide(file: "03-wardrobe", raw: "p4-wardrobe", eyebrow: "피오 옷장", headline: "계절마다\n피오를 꾸며요", sub: "벚꽃부터 우주복까지 13가지 의상", accent: coral),
    Slide(file: "04-app-icon", raw: "p6-icons", eyebrow: "앱 아이콘", headline: "홈 화면도\n내 피오로", sub: "산 의상의 피오로 앱 아이콘을 바꿔요", accent: orange),
    Slide(file: "05-routines", raw: "p3-routines", eyebrow: "루틴 관리", headline: "그룹과 시간으로\n깔끔하게 정리", sub: "요일과 시간을 루틴마다 정해 두세요", accent: purple),
    Slide(file: "06-meals", raw: "p5-meals", eyebrow: "식사 기록", headline: "하루 세 끼도\n가볍게 남겨요", sub: "적으면 자동으로 저장돼요", accent: yellow),
]
let padSlides = [
    Slide(file: "01-today", raw: "d1-today", eyebrow: "iPad", headline: "넓은 화면에서\n하루를 한눈에", sub: "루틴과 식사, 피오의 성장을 한 화면에", accent: mint),
    Slide(file: "02-statistics", raw: "d2-stats", eyebrow: "통계", headline: "꾸준함이\n그래프로 보여요", sub: "달성률 추이와 활동 히트맵", accent: blue),
    Slide(file: "03-wardrobe", raw: "d3-wardrobe", eyebrow: "피오 옷장", headline: "계절마다\n피오를 꾸며요", sub: "한 번 사면 iPhone·iPad·Mac에서 모두 입어요", accent: coral),
    Slide(file: "04-calendar", raw: "d4-calendar", eyebrow: "캘린더 · 휴가", headline: "쉬는 날도\n계획대로", sub: "휴가는 통계에서 빠지고, 날짜마다 기록이 남아요", accent: orange),
    Slide(file: "05-routines", raw: "d5-routines", eyebrow: "루틴 관리", headline: "그룹으로 나누고\n시간까지 정리", sub: "요일과 시간을 루틴마다 정해 두세요", accent: purple),
]
let macSlides = [
    Slide(file: "01-today", raw: "m1-today", eyebrow: "Mac", headline: "책상 위에서도 피오와 함께", sub: "루틴, 식사, 달성 현황을 한 화면에", accent: mint),
    Slide(file: "02-statistics", raw: "m2-stats", eyebrow: "통계", headline: "작은 실천이 쌓이는 순간", sub: "달성률 추이와 연속 기록으로 변화를 확인하세요", accent: blue),
    Slide(file: "03-wardrobe", raw: "m3-wardrobe", eyebrow: "피오 옷장", headline: "한 번 사면 모든 기기에서", sub: "iPhone·iPad에서 산 의상도 Mac에서 그대로 입어요", accent: coral),
    Slide(file: "04-calendar", raw: "m4-calendar", eyebrow: "캘린더 · 휴가", headline: "쉬는 날도 계획대로", sub: "날짜를 누르면 그날의 루틴과 식사를 볼 수 있어요", accent: orange),
    Slide(file: "05-routines", raw: "m5-routines", eyebrow: "루틴 관리", headline: "그룹과 시간으로 깔끔하게", sub: "iCloud로 iPhone·iPad와 바로 이어져요", accent: purple),
]

let targets = [
    Target(name: "iphone-6.9", rawDir: "iphone-2026-10-26", size: CGSize(width: 1320, height: 2868), base: CGSize(width: 1320, height: 2868), isPad: false, slides: phoneSlides),
    Target(name: "iphone-6.3", rawDir: "iphone-2026-10-26", size: CGSize(width: 1206, height: 2622), base: CGSize(width: 1320, height: 2622.0 * 1320.0 / 1206.0), isPad: false, slides: phoneSlides),
    Target(name: "ipad-13", rawDir: "ipad-2026-10-26", size: CGSize(width: 2064, height: 2752), base: CGSize(width: 2064, height: 2752), isPad: true, slides: padSlides),
    Target(name: "mac", rawDir: "mac-2026-10-26", size: CGSize(width: 2560, height: 1600), base: CGSize(width: 2560, height: 1600), isPad: true, slides: macSlides),
]

func color(_ c: (CGFloat, CGFloat, CGFloat), _ alpha: CGFloat = 1, mix white: CGFloat = 0) -> NSColor {
    func m(_ v: CGFloat) -> CGFloat { (v + (255 - v) * white) / 255 }
    return NSColor(srgbRed: m(c.0), green: m(c.1), blue: m(c.2), alpha: alpha)
}
func darker(_ c: (CGFloat, CGFloat, CGFloat), _ k: CGFloat) -> NSColor {
    NSColor(srgbRed: c.0 * k / 255, green: c.1 * k / 255, blue: c.2 * k / 255, alpha: 1)
}

/// 위에서부터 잰 좌표로 가운데 정렬 글을 그리고, 차지한 높이를 돌려준다.
@discardableResult
func drawText(_ text: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor, canvas: CGSize,
              lineHeight: CGFloat = 1.2, kern: CGFloat = 0, inset: CGFloat = 80) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.minimumLineHeight = size * lineHeight
    paragraph.maximumLineHeight = size * lineHeight
    paragraph.lineBreakStrategy = .hangulWordPriority
    let attributed = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph, .kern: kern,
    ])
    let width = canvas.width - inset * 2
    let bounds = attributed.boundingRect(with: CGSize(width: width, height: 4000), options: [.usesLineFragmentOrigin, .usesFontLeading])
    let height = ceil(bounds.height)
    attributed.draw(with: CGRect(x: inset, y: canvas.height - top - height, width: width, height: height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading])
    return height
}

func render(_ target: Target, _ slide: Slide, root: String) throws {
    let W = Int(target.size.width), H = Int(target.size.height)
    guard let cg = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                             space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw NSError(domain: "compose", code: 1)
    }
    let scale = target.size.width / target.base.width
    cg.scaleBy(x: scale, y: scale)
    let canvas = target.base
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
    cg.interpolationQuality = .high

    // 배경: 옅은 강조색에서 거의 흰색으로. 뒤에 부드러운 빛 두 덩이.
    let top = color(slide.accent, mix: 0.78), bottom = color(slide.accent, mix: 0.93)
    NSGradient(starting: bottom, ending: top)!.draw(in: CGRect(origin: .zero, size: canvas), angle: 90)
    func glow(_ center: CGPoint, _ radius: CGFloat, _ alpha: CGFloat) {
        let g = NSGradient(starting: color(slide.accent, alpha, mix: 0.35), ending: color(slide.accent, 0, mix: 0.35))!
        g.draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
    }
    glow(CGPoint(x: canvas.width * 0.88, y: canvas.height * 0.93), canvas.width * 0.62, 0.42)
    glow(CGPoint(x: canvas.width * 0.06, y: canvas.height * 0.52), canvas.width * 0.55, 0.26)

    // 문구
    let isMac = target.name == "mac"
    let m: (eyebrowTop: CGFloat, eyebrowSize: CGFloat, headlineSize: CGFloat, subSize: CGFloat, gap1: CGFloat, gap2: CGFloat) =
        isMac ? (64, 34, 86, 38, 26, 16) : target.isPad ? (112, 46, 128, 52, 44, 30) : (112, 42, 112, 45, 38, 28)
    let ink = NSColor(srgbRed: 0x12 / 255, green: 0x24 / 255, blue: 0x20 / 255, alpha: 1)
    let subInk = NSColor(srgbRed: 0x55 / 255, green: 0x66 / 255, blue: 0x62 / 255, alpha: 1)

    // 작은 머리말은 흰 알약 안에.
    let eyebrowFont = NSFont.systemFont(ofSize: m.eyebrowSize, weight: .bold)
    let eyebrowText = NSAttributedString(string: slide.eyebrow, attributes: [.font: eyebrowFont, .foregroundColor: darker(slide.accent, 0.58), .kern: 0.5])
    let eyebrowSize = eyebrowText.size()
    let pill = CGRect(x: (canvas.width - eyebrowSize.width) / 2 - m.eyebrowSize * 0.75, y: canvas.height - m.eyebrowTop - m.eyebrowSize * 1.9,
                      width: eyebrowSize.width + m.eyebrowSize * 1.5, height: m.eyebrowSize * 1.9)
    NSColor(white: 1, alpha: 0.82).setFill()
    NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
    eyebrowText.draw(at: CGPoint(x: (canvas.width - eyebrowSize.width) / 2, y: pill.midY - eyebrowSize.height / 2))

    var y = m.eyebrowTop + pill.height + m.gap1
    y += drawText(slide.headline, top: y, size: m.headlineSize, weight: .heavy, color: ink, canvas: canvas, lineHeight: 1.2, kern: -1.5)
    y += m.gap2
    y += drawText(slide.sub, top: y, size: m.subSize, weight: .medium, color: subInk, canvas: canvas, lineHeight: 1.3)

    // 기기: 실제 캡처를 비율 그대로 놓는다.
    let rawPath = "\(root)/AppStore/raw/\(target.rawDir)/\(slide.raw).png"
    guard let image = NSImage(contentsOfFile: rawPath), let rep = image.representations.first else {
        throw NSError(domain: "compose", code: 2, userInfo: [NSLocalizedDescriptionKey: "원본 캡처가 없습니다: \(rawPath)"])
    }
    let aspect = CGFloat(rep.pixelsHigh) / CGFloat(rep.pixelsWide)
    if isMac {
        // Mac: 창 캡처를 실제 픽셀 그대로(1:1) 가운데 놓는다. 창 모서리·그림자만 더하고 기기 테두리는 없다.
        let screenWidth = CGFloat(rep.pixelsWide), screenHeight = CGFloat(rep.pixelsHigh)
        let windowTop = y + 44
        let screen = CGRect(x: (canvas.width - screenWidth) / 2, y: canvas.height - windowTop - screenHeight, width: screenWidth, height: screenHeight)
        let path = NSBezierPath(roundedRect: screen, xRadius: 22, yRadius: 22)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -24), blur: 90, color: darker(slide.accent, 0.32).withAlphaComponent(0.32).cgColor)
        NSColor.white.setFill(); path.fill()
        cg.restoreGState()
        cg.saveGState(); path.addClip()
        image.draw(in: screen, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
        cg.restoreGState()
        NSColor(white: 0, alpha: 0.12).setStroke(); path.lineWidth = 2; path.stroke()
        return try save(cg, target, slide, root: root, W: W, H: H)
    }
    let deviceTop = y + (target.isPad ? 70 : 62)
    let bezel: CGFloat = target.isPad ? 22 : 15
    // iPhone은 화면 전체가 잘리지 않게 남은 높이에 맞춘다.
    // iPad는 화면 속 글자가 작아서, 크게 놓고 아래쪽을 조금 넘긴다(위에서부터 88%쯤 보인다).
    let available = canvas.height - deviceTop - bezel * 2 - 50
    let screenWidth = target.isPad ? canvas.width * 0.86 : min(canvas.width * 0.80, available / aspect)
    let screenHeight = screenWidth * aspect
    let screen = CGRect(x: (canvas.width - screenWidth) / 2, y: canvas.height - deviceTop - bezel - screenHeight, width: screenWidth, height: screenHeight)
    let radius = screenWidth * (target.isPad ? 0.022 : 0.128)
    let body = screen.insetBy(dx: -bezel, dy: -bezel)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: radius + bezel, yRadius: radius + bezel)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -canvas.width * 0.03), blur: canvas.width * 0.075,
                 color: darker(slide.accent, 0.32).withAlphaComponent(0.34).cgColor)
    NSColor(srgbRed: 0.055, green: 0.075, blue: 0.07, alpha: 1).setFill()
    bodyPath.fill()
    cg.restoreGState()
    // 테두리 가장자리의 옅은 빛.
    NSColor(white: 1, alpha: 0.16).setStroke()
    let rim = NSBezierPath(roundedRect: body.insetBy(dx: 1.5, dy: 1.5), xRadius: radius + bezel - 1.5, yRadius: radius + bezel - 1.5)
    rim.lineWidth = 3
    rim.stroke()

    cg.saveGState()
    NSBezierPath(roundedRect: screen, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: screen, from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    cg.restoreGState()

    if !target.isPad {
        // Dynamic Island: 캡처에는 찍히지 않는 기기의 일부.
        let islandWidth = screenWidth * 0.285, islandHeight = screenWidth * 0.084
        let island = CGRect(x: screen.midX - islandWidth / 2, y: screen.maxY - screenWidth * 0.032 - islandHeight, width: islandWidth, height: islandHeight)
        NSColor.black.setFill()
        NSBezierPath(roundedRect: island, xRadius: islandHeight / 2, yRadius: islandHeight / 2).fill()
    }

    try save(cg, target, slide, root: root, W: W, H: H)
}

func save(_ cg: CGContext, _ target: Target, _ slide: Slide, root: String, W: Int, H: Int) throws {
    NSGraphicsContext.current = nil
    guard let output = cg.makeImage() else { throw NSError(domain: "compose", code: 3) }
    let directory = "\(root)/AppStore/screenshots-2026-10-26/\(target.name)"
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    let url = URL(fileURLWithPath: "\(directory)/\(slide.file).png")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { throw NSError(domain: "compose", code: 4) }
    CGImageDestinationAddImage(destination, output, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "compose", code: 5) }
    print("\(target.name)/\(slide.file).png  \(W)x\(H)")
}

let root = FileManager.default.currentDirectoryPath
do {
    for target in targets { for slide in target.slides { try render(target, slide, root: root) } }
} catch {
    FileHandle.standardError.write("실패: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
