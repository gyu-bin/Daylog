import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 사용법: eyes <레이어 폴더>
// 눈 위에 겹치는 표정 세 장(감은 눈·웃는 눈·졸린 눈)을 만든다. 1536 캔버스, 마스터와 같은 좌표.
// 피부는 몸 레이어(눈 밑을 메운 피부)를 그대로 잘라 쓰고, 감은 눈의 선은 두께가 변하는 갈색 곡선에 그림자를 넣어
// 납작한 펜 선이 아니라 둥근 얼굴 위의 눈매처럼 보이게 한다.
let dir = URL(fileURLWithPath: CommandLine.arguments[1])
let S = 1536
func load(_ n: String) -> CGImage {
    let s = CGImageSourceCreateWithURL(dir.appendingPathComponent(n + ".png") as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(s, 0, nil)!
}
let body = load("body")
let space = CGColorSpace(name: CGColorSpace.sRGB)!
// 눈 타원(원화 좌표, 위가 원점): 가운데와 반지름
let eyes: [(x: Double, y: Double, rx: Double, ry: Double)] = [(617, 847, 57, 63), (921.5, 846.5, 56.5, 63.5)]
func Y(_ y: Double) -> Double { Double(S) - y }

enum Face { case closed, happy, sleepy }

func make(_ face: Face, name: String) {
    let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    for e in eyes {
        // 1. 피부: 눈을 덮는다(졸린 눈은 위쪽 절반쯤만)
        ctx.saveGState()
        ctx.beginPath()
        let cover = CGRect(x: e.x - e.rx - 16, y: Y(e.y) - e.ry - 16, width: (e.rx + 16) * 2, height: (e.ry + 16) * 2)
        if face == .sleepy {
            // 눈꺼풀 아래 선: 가운데가 조금 처진 곡선
            let lid = CGMutablePath()
            lid.move(to: CGPoint(x: cover.minX, y: cover.maxY))
            lid.addLine(to: CGPoint(x: cover.maxX, y: cover.maxY))
            lid.addLine(to: CGPoint(x: cover.maxX, y: Y(e.y + 0.02 * e.ry)))
            lid.addQuadCurve(to: CGPoint(x: cover.minX, y: Y(e.y + 0.02 * e.ry)), control: CGPoint(x: e.x, y: Y(e.y + 0.34 * e.ry)))
            lid.closeSubpath()
            ctx.addPath(lid)
        } else {
            ctx.addEllipse(in: cover)
        }
        ctx.clip()
        ctx.draw(body, in: CGRect(x: 0, y: 0, width: S, height: S))
        // 둥근 눈꺼풀의 볼륨(아주 옅게): 감은 눈은 위 눈꺼풀이 불룩해 눈매 쪽으로 살짝 그늘지고 위쪽에 빛이 닿는다.
        // 웃는 눈은 볼이 밀려 올라와 눈매 아래가 살짝 그늘진다. 둘 다 피부 위의 반투명 그라데이션이라 질감은 그대로다.
        if face != .sleepy {
            let lineY = face == .closed ? e.y + 0.32 * e.ry : e.y - 0.16 * e.ry
            let shade = CGGradient(colorsSpace: space, colors: [
                CGColor(red: 0.55, green: 0.32, blue: 0.14, alpha: 0.10), CGColor(red: 0.55, green: 0.32, blue: 0.14, alpha: 0),
            ] as CFArray, locations: [0, 1])!
            ctx.drawRadialGradient(shade, startCenter: CGPoint(x: e.x, y: Y(lineY)), startRadius: 0,
                                   endCenter: CGPoint(x: e.x, y: Y(lineY)), endRadius: e.rx * 0.95, options: [])
            let light = CGGradient(colorsSpace: space, colors: [
                CGColor(red: 1, green: 0.99, blue: 0.94, alpha: 0.16), CGColor(red: 1, green: 0.99, blue: 0.94, alpha: 0),
            ] as CFArray, locations: [0, 1])!
            let lightY = face == .closed ? e.y - 0.30 * e.ry : e.y + 0.42 * e.ry
            ctx.drawRadialGradient(light, startCenter: CGPoint(x: e.x - 0.12 * e.rx, y: Y(lightY)), startRadius: 0,
                                   endCenter: CGPoint(x: e.x - 0.12 * e.rx, y: Y(lightY)), endRadius: e.rx * 0.6, options: [])
        }
        ctx.restoreGState()

        // 2. 선(눈매): 가운데가 두껍고 양 끝으로 갈수록 가늘어지는 하나의 면 + 아래로 번지는 부드러운 그림자
        let half = e.rx * (face == .sleepy ? 0.98 : 0.9)
        let (y0, yc): (Double, Double) = switch face {
        case .closed: (0.02, 0.62)
        case .happy: (0.30, -0.62)
        case .sleepy: (0.02, 0.34)
        }
        let p0 = (e.x - half, e.y + y0 * e.ry), p2 = (e.x + half, e.y + y0 * e.ry), c = (e.x, e.y + yc * e.ry)
        let width = e.ry * (face == .sleepy ? 0.12 : 0.18)
        var top: [CGPoint] = [], bottom: [CGPoint] = []
        let count = 48
        for k in 0...count {
            let t = Double(k) / Double(count), u = 1 - t
            let x = u * u * p0.0 + 2 * u * t * c.0 + t * t * p2.0, y = u * u * p0.1 + 2 * u * t * c.1 + t * t * p2.1
            let dx = 2 * u * (c.0 - p0.0) + 2 * t * (p2.0 - c.0), dy = 2 * u * (c.1 - p0.1) + 2 * t * (p2.1 - c.1)
            let len = max((dx * dx + dy * dy).squareRoot(), 1e-6)
            let nx = -dy / len, ny = dx / len
            // 굵기: 가운데 1, 끝 0.25(둥근 끝)
            let w = width / 2 * (0.25 + 0.75 * pow(sin(.pi * t), 0.7))
            top.append(CGPoint(x: x + nx * w, y: Y(y + ny * w)))
            bottom.append(CGPoint(x: x - nx * w, y: Y(y - ny * w)))
        }
        let shape = CGMutablePath()
        shape.addLines(between: top + bottom.reversed())
        shape.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 7, color: CGColor(red: 0.45, green: 0.22, blue: 0.08, alpha: 0.4))
        ctx.beginPath()
        ctx.addPath(shape)
        ctx.setFillColor(CGColor(red: 0.24, green: 0.13, blue: 0.07, alpha: 1))
        ctx.fillPath()
        ctx.restoreGState()
        // 둥근 끝
        for (end, point) in [(0, top[0]), (1, top[count])] {
            let other = end == 0 ? bottom[0] : bottom[count]
            let r = hypot(point.x - other.x, point.y - other.y) / 2
            ctx.beginPath()
            ctx.addEllipse(in: CGRect(x: (point.x + other.x) / 2 - r, y: (point.y + other.y) / 2 - r, width: r * 2, height: r * 2))
            ctx.setFillColor(CGColor(red: 0.24, green: 0.13, blue: 0.07, alpha: 1))
            ctx.fillPath()
        }
    }
    let dest = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}
make(.closed, name: "eyes_closed")
make(.happy, name: "eyes_happy")
make(.sleepy, name: "eyes_sleepy")
