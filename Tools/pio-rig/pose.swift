import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 사용법: pose <레이어 폴더> <출력.png> <배경 RRGGBB|none> [키=값 …]
// 키: wingL, wingR, crest(도, 시계 방향 +), footLdy, footRdy(위로 px), footLrot, footRrot(도), eyes(세로 배율), lid(0…1 감은 눈 겹침)
// 레이어를 원화 좌표의 기준점 둘레로 돌리고 옮겨 한 장으로 합친다(앱의 레이어 구조와 같은 순서: 발 → 몸 → 날개 → 볏 → 눈).
let a = CommandLine.arguments
let dir = URL(fileURLWithPath: a[1])
var params: [String: Double] = [:]
for kv in a.dropFirst(4) { let p = kv.split(separator: "="); params[String(p[0])] = Double(p[1])! }
func v(_ k: String) -> Double { params[k] ?? 0 }
func load(_ n: String) -> CGImage? {
    guard let s = CGImageSourceCreateWithURL(dir.appendingPathComponent(n + ".png") as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(s, 0, nil)
}
let S = 1536
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
if a[3] != "none", let n = UInt32(a[3], radix: 16) {
    ctx.setFillColor(red: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255, blue: CGFloat(n & 255) / 255, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
}
// CG는 아래가 원점: 원화 좌표(위가 원점)를 바꿔 쓴다
func draw(_ name: String, pivot: (Double, Double), angle: Double = 0, dx: Double = 0, dy: Double = 0, sy: Double = 1) {
    guard let img = load(name) else { return }
    ctx.saveGState()
    let px = pivot.0, py = Double(S) - pivot.1
    ctx.translateBy(x: px + dx, y: py + dy)
    ctx.rotate(by: -angle * .pi / 180)
    ctx.scaleBy(x: 1, y: sy)
    ctx.translateBy(x: -px, y: -py)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: S, height: S))
    ctx.restoreGState()
}
draw("foot_left", pivot: (615, 1235), angle: v("footLrot"), dy: v("footLdy"))
draw("foot_right", pivot: (918, 1235), angle: v("footRrot"), dy: v("footRdy"))
draw("body", pivot: (768, 768))
// 접촉 그림자는 날개에 붙어 같이 돌고, 날개가 몸에서 떨어질수록(각도가 클수록) 옅어진다
ctx.setAlpha(max(0, 1 - abs(v("wingL")) / 18)); draw("wing_left_shadow", pivot: (482, 940), angle: v("wingL")); ctx.setAlpha(1)
ctx.setAlpha(max(0, 1 - abs(v("wingR")) / 18)); draw("wing_right_shadow", pivot: (1054, 940), angle: v("wingR")); ctx.setAlpha(1)
draw("wing_left", pivot: (482, 940), angle: v("wingL"))
draw("wing_right", pivot: (1054, 940), angle: v("wingR"))
draw("crest", pivot: (745, 588), angle: v("crest"))
let eyes = v("eyes") == 0 ? 1 : v("eyes")
// 눈은 각자의 가운데를 기준으로 세로로 접는다
ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: 0, width: 768, height: S)); draw("eyes", pivot: (617, 847), sy: eyes); ctx.restoreGState()
ctx.saveGState(); ctx.clip(to: CGRect(x: 768, y: 0, width: 768, height: S)); draw("eyes", pivot: (921.5, 846.5), sy: eyes); ctx.restoreGState()
if v("lid") > 0, let lid = load(params["happy"] == 1 ? "eyes_happy" : (params["sleepy"] == 1 ? "eyes_sleepy" : "eyes_closed")) {
    ctx.setAlpha(v("lid")); ctx.draw(lid, in: CGRect(x: 0, y: 0, width: S, height: S)); ctx.setAlpha(1)
}
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
