// Daylog 앱 아이콘을 벡터로 그려 PNG로 내보낸다. 시안 이미지를 확대하지 않고, 시안에서 잰 경계와 색으로 다시 그린다.
//
//     swiftc -O Tools/GenerateIcons.swift -o /tmp/daylog-icons && /tmp/daylog-icons Daylog/Assets.xcassets
//
// 만드는 것
// - BrandIcon.imageset/DaylogIconLight.png, DaylogIconDark.png : 1024×1024, 여백 없이 꽉 찬 둥근 사각형(앱 안에서 쓰는 브랜드 아이콘)
// - AppIcon.appiconset/icon_*.png : macOS 아이콘 격자(바깥 여백과 그림자 포함)에 맞춘 라이트 아이콘. 크기마다 따로 그린다.
// - DockIconDark.imageset/DockIconDark.png : 같은 격자의 다크 아이콘(실행 중 Dock 아이콘 교체용)
import AppKit
import SwiftUI

enum Style { case light, dark }
enum Layout { case fullBleed, macGrid }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func gradient(_ stops: [(CGFloat, UInt32)]) -> CGGradient {
    CGGradient(colorsSpace: sRGB, colors: stops.map { color($0.1) } as CFArray, locations: stops.map(\.0))!
}

/// 시안에서 잰 좌표(가로·세로를 각각 0...1000으로 정규화한 값)를 정사각형 좌표로 옮긴다.
/// 시안의 아이콘 상자는 639×616이라, 세로를 그 비율로 줄이고 가운데에 둔다(로고의 비율 유지).
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: x, y: y * 0.964 + 18)
}

/// 점들을 부드럽게 잇는 곡선(Catmull-Rom). 양 끝은 뾰족하게 둔다.
func addSpline(_ path: CGMutablePath, _ points: [CGPoint], moveToStart: Bool) {
    guard points.count > 1 else { return }
    if moveToStart { path.move(to: points[0]) }
    for i in 0..<(points.count - 1) {
        let p0 = points[max(i - 1, 0)], p1 = points[i], p2 = points[i + 1], p3 = points[min(i + 2, points.count - 1)]
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        path.addCurve(to: p2, control1: c1, control2: c2)
    }
}

// MARK: - 시안에서 잰 모양

let tip = P(185, 212), tail = P(801, 893), veinStart = P(345, 492)

/// 잎의 위쪽 가장자리: 왼쪽 끝 → 오른쪽 아래 끝.
let topEdge: [CGPoint] = [tip, P(222, 260), P(270, 300), P(340, 331), P(420, 352), P(500, 366), P(580, 387), P(660, 426),
                          P(740, 491), P(798, 580), P(823, 660), P(830, 740), P(826, 810), P(815, 860), tail]
/// 잎의 아래·왼쪽 가장자리: 오른쪽 아래 끝 → 왼쪽 끝.
let bottomEdge: [CGPoint] = [tail, P(780, 878), P(740, 862), P(700, 853), P(660, 850), P(600, 854), P(540, 860), P(500, 862),
                             P(460, 858), P(420, 850), P(380, 837), P(340, 818), P(300, 788), P(260, 751), P(222, 700),
                             P(192, 640), P(167, 560), P(155, 480), P(154, 420), P(158, 360), P(166, 290), P(176, 245), tip]
/// 잎맥(흰 초승달)의 위쪽·아래쪽 가장자리.
let veinUpper: [CGPoint] = [veinStart, P(378, 520), P(403, 540), P(433, 560), P(469, 580), P(511, 600), P(560, 620), P(608, 640),
                            P(643, 660), P(671, 680), P(715, 720), P(746, 760), P(766, 800), P(785, 840), P(797, 875), tail]
let veinLower: [CGPoint] = [tail, P(806, 860), P(808, 830), P(802, 800), P(788, 760), P(765, 720), P(733, 680), P(688, 640),
                            P(654, 620), P(615, 600), P(561, 580), P(489, 560), P(435, 540), P(392, 520), veinStart]
/// 위쪽 잎면과 왼쪽 잎면이 만나는 접힌 선: 잎맥의 시작점 → 왼쪽 끝.
let crease: [CGPoint] = [veinStart, P(305, 456), P(252, 382), P(212, 300), tip]
/// 잎과 태양 사이의 밝은 테두리(위쪽 경계).
let rimUpper: [CGPoint] = [P(452, 357), P(500, 355), P(540, 358), P(580, 366), P(620, 379), P(660, 397), P(700, 425), P(740, 462),
                           P(775, 505), P(800, 560)]
let sunCenter = P(660, 330)
let sunRadius: CGFloat = 186

func leafPath() -> CGPath {
    let path = CGMutablePath()
    addSpline(path, topEdge, moveToStart: true)
    addSpline(path, bottomEdge, moveToStart: false)
    path.closeSubpath()
    return path
}

/// 위쪽 잎면. 아래 경계를 잎맥의 아래쪽 가장자리까지 내려서, 그 위에 잎맥을 덮어 그릴 때 틈이 생기지 않게 한다.
func upperLobePath() -> CGPath {
    let path = CGMutablePath()
    addSpline(path, topEdge, moveToStart: true)
    addSpline(path, veinLower, moveToStart: false)
    addSpline(path, crease, moveToStart: false)
    path.closeSubpath()
    return path
}

func veinPath() -> CGPath {
    let path = CGMutablePath()
    addSpline(path, veinUpper, moveToStart: true)
    addSpline(path, veinLower, moveToStart: false)
    path.closeSubpath()
    return path
}

func rimPath() -> CGPath {
    let path = CGMutablePath()
    addSpline(path, rimUpper, moveToStart: true)
    // 잎의 위쪽 가장자리를 거꾸로 따라 돌아온다(조금 안쪽까지 겹쳐 틈을 없앤다).
    let lower = topEdge.filter { $0.x >= 400 && $0.x <= 800 }.reversed().map { CGPoint(x: $0.x, y: $0.y + 6) }
    path.addLine(to: lower[0])
    addSpline(path, Array(lower), moveToStart: false)
    path.closeSubpath()
    return path
}

// MARK: - 그리기

/// `rect`(왼쪽 위가 원점인 좌표) 안에 아이콘 한 개를 그린다.
func drawIcon(_ ctx: CGContext, in rect: CGRect, style: Style, withDropShadow: Bool) {
    let radius = rect.width * 0.225
    let squircle = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath

    if withDropShadow {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: rect.width * 0.012), blur: rect.width * 0.03, color: color(0x000000, 0.28))
        ctx.addPath(squircle)
        ctx.setFillColor(color(style == .light ? 0xF8FAF3 : 0x173F45))
        ctx.fillPath()
        ctx.restoreGState()
    }

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // 배경
    let background = style == .light
        ? gradient([(0, 0xFFFDF8), (0.5, 0xF8FAF3), (1, 0xEAF4EB)])
        : gradient([(0, 0x2E525B), (0.45, 0x173F45), (1, 0x0B3238)])
    ctx.drawLinearGradient(background, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    if style == .dark {
        let glow = CGGradient(colorsSpace: sRGB, colors: [color(0x2A6A70, 0.55), color(0x2A6A70, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.maxY - rect.height * 0.05), startRadius: 0,
                               endCenter: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.maxY - rect.height * 0.05), endRadius: rect.width * 0.5, options: [])
    }

    // 이후는 0...1000 좌표로 그린다.
    ctx.translateBy(x: rect.minX, y: rect.minY)
    ctx.scaleBy(x: rect.width / 1000, y: rect.height / 1000)

    let leaf = leafPath()
    let sun = CGPath(ellipseIn: CGRect(x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2), transform: nil)

    // 태양
    ctx.saveGState()
    ctx.addPath(sun)
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0, 0xFDE2A0), (0.5, 0xFFC48D), (1, 0xFFA672)]), start: P(585, 150), end: P(790, 460),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // 잎의 그림자. 테두리보다 먼저 그려서 테두리가 탁해지지 않게 한다.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 22 * rect.width / 1000), blur: 46 * rect.width / 1000,
                  color: style == .light ? color(0x2F8F6A, 0.22) : color(0x000000, 0.38))
    ctx.addPath(leaf)
    ctx.setFillColor(color(0x17BBA0))
    ctx.fillPath()
    ctx.restoreGState()

    // 잎과 태양 사이의 밝은 테두리. 라이트에서는 배경색이라 틈처럼 보인다.
    ctx.saveGState()
    ctx.addPath(sun)
    ctx.clip()
    ctx.addPath(rimPath())
    ctx.setFillColor(color(style == .light ? 0xFFFCF2 : 0xFDF9EE))
    ctx.fillPath()
    ctx.restoreGState()

    // 잎: 아래쪽 잎면(왼쪽 가장자리가 밝고 오른쪽으로 갈수록 짙다) → 왼쪽 아래의 밝은 빛 → 위쪽 잎면 → 잎맥
    ctx.saveGState()
    ctx.addPath(leaf)
    ctx.clip()
    let lower = style == .light
        ? gradient([(0, 0x34C58B), (0.10, 0x1DB98A), (0.18, 0x14B187), (0.48, 0x11AB8A), (0.65, 0x069F87), (0.78, 0x009483), (1, 0x00917E)])
        : gradient([(0, 0x3AD6A7), (0.10, 0x18C5A1), (0.18, 0x0CBC9C), (0.48, 0x17BAA0), (0.65, 0x06A692), (0.78, 0x009084), (1, 0x00877D)])
    ctx.drawLinearGradient(lower, start: CGPoint(x: 150, y: 500), end: CGPoint(x: 780, y: 500), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    let glowColor: UInt32 = style == .light ? 0x70D28A : 0x8AECAD
    let glow = CGGradient(colorsSpace: sRGB, colors: [color(glowColor, 0.95), color(glowColor, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: P(175, 700), startRadius: 0, endCenter: P(175, 700), endRadius: 330, options: [])
    ctx.addPath(upperLobePath())
    ctx.clip()
    let upper = style == .light
        ? gradient([(0, 0x68DCA8), (0.15, 0x86E9B0), (0.3, 0x79E2B1), (0.5, 0x48CFB0), (0.7, 0x1ABDAE), (0.93, 0x00A69D), (1, 0x009B8E)])
        : gradient([(0, 0x6FE3B0), (0.15, 0x8AEEB5), (0.3, 0x76E4B6), (0.5, 0x44D0B2), (0.7, 0x10BBAE), (0.93, 0x00A09C), (1, 0x009C98)])
    ctx.drawLinearGradient(upper, start: P(250, 380), end: P(830, 760), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    ctx.addPath(veinPath())
    ctx.setFillColor(color(style == .light ? 0xFEFEFB : 0xFCFEFB))
    ctx.fillPath()
    ctx.restoreGState()

    // 가장자리의 옅은 안쪽 선
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    ctx.addPath(squircle)
    ctx.setStrokeColor(style == .light ? color(0xFFFFFF, 0.7) : color(0xFFFFFF, 0.10))
    ctx.setLineWidth(max(1, rect.width * 0.006))
    ctx.strokePath()
    ctx.restoreGState()
}

func render(size: Int, style: Style, layout: Layout) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    // 왼쪽 위를 원점으로
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    let s = CGFloat(size)
    switch layout {
    case .fullBleed:
        drawIcon(ctx, in: CGRect(x: 0, y: 0, width: s, height: s), style: style, withDropShadow: false)
    case .macGrid:
        // macOS 아이콘 격자: 1024 기준 824×824의 둥근 사각형과 바깥 여백 100
        let inset = s * 100 / 1024
        drawIcon(ctx, in: CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2), style: style, withDropShadow: true)
    }
    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("쓰기 실패: \(url.path)") }
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
write(render(size: 1024, style: .light, layout: .fullBleed), to: root.appendingPathComponent("BrandIcon.imageset/DaylogIconLight.png"))
write(render(size: 1024, style: .dark, layout: .fullBleed), to: root.appendingPathComponent("BrandIcon.imageset/DaylogIconDark.png"))
write(render(size: 1024, style: .dark, layout: .macGrid), to: root.appendingPathComponent("DockIconDark.imageset/DockIconDark.png"))
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    write(render(size: points * scale, style: .light, layout: .macGrid), to: root.appendingPathComponent("AppIcon.appiconset/\(name)"))
}
print("done")
