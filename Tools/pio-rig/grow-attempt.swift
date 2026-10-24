import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 사용법: grow <레이어 폴더>
// 피오 성장 단계의 볏·날개·꼬리 레이어를 만든다. 새 깃털은 그리지 않는다: 마스터에서 잘라 낸 완전한 3D 깃털 두 가지
// (앞쪽 노란 깃털 하나, 주황 볏)를 그대로 옮겨 돌리고 크기만 바꿔 겹친다. 모두 1536 캔버스·마스터와 같은 좌표.
// 빛이 왼쪽 위에서 오는 원화라, 옮긴 깃털도 빛이 위쪽에서 오도록(좌우 뒤집기와 회전을 합쳐) 놓는다.
let dir = URL(fileURLWithPath: CommandLine.arguments[1])
let S = 1536, N = S * S
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func load(_ name: String) -> [UInt8] {
    let src = CGImageSourceCreateWithURL(dir.appendingPathComponent(name + ".png") as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    var px = [UInt8](repeating: 0, count: N * 4)
    CGContext(data: &px, width: S, height: S, bitsPerComponent: 8, bytesPerRow: S * 4, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.draw(img, in: CGRect(x: 0, y: 0, width: S, height: S))
    return px
}
func image(_ px: [UInt8]) -> CGImage {
    var copy = px
    return CGContext(data: &copy, width: S, height: S, bitsPerComponent: 8, bytesPerRow: S * 4, space: space,
                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
}
func save(_ img: CGImage, _ name: String) {
    let dest = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}
typealias P = (x: Double, y: Double)
func inside(_ poly: [P], _ x: Double, _ y: Double) -> Bool {
    var c = false; var j = poly.count - 1
    for i in 0..<poly.count { let a = poly[i], b = poly[j]
        if (a.y > y) != (b.y > y), x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x { c.toggle() }; j = i }
    return c
}

let crest = load("crest")
// 앞쪽 노란 깃털: 확대 그림에서 딴 윤곽 안의 노란 픽셀(주황 볏은 빼고)
let tuftPoly: [P] = [(565, 930), (590, 850), (630, 790), (690, 750), (760, 730), (830, 732), (880, 755), (902, 800), (895, 850),
                     (860, 890), (800, 915), (720, 935), (620, 945)].map { (440 + $0.0 / 2, 120 + $0.1 / 2) }
var tuft = [UInt8](repeating: 0, count: N * 4), plume = tuft
for y in 380..<640 { for x in 500..<1120 {
    let i = (y * S + x) * 4
    let a = Double(crest[i + 3]); guard a > 0 else { continue }
    let r = Double(crest[i]), g = Double(crest[i + 1])
    let yellow = g / max(r, 1) >= 0.66
    if yellow, inside(tuftPoly, Double(x) + 0.5, Double(y) + 0.5) { for k in 0..<4 { tuft[i + k] = crest[i + k] } }
} }
// 주황 볏: 윤곽(확대 그림에서 딴 다각형) 안의 픽셀. 앞쪽 노란 깃털에 가린 밑동은 둘레 주황색에서 매끄럽게 메운다.
let plumeRaw: [(Double, Double)] = [(500, 760), (495, 640), (520, 520), (580, 420), (660, 330), (760, 250), (880, 205), (990, 195),
    (1100, 215), (1190, 280), (1235, 380), (1235, 470), (1200, 560), (1130, 640), (1040, 700), (940, 740), (840, 770), (700, 830),
    (600, 900), (565, 930)]
let plumePoly: [P] = plumeRaw.map { p -> P in (440 + p.0 / 2, 120 + p.1 / 2) }
var hole = [Bool](repeating: false, count: N), known = hole
var pr = [Double](repeating: 0, count: N), pg = pr, pb = pr
for y in 150..<620 { for x in 600..<1120 {
    let i = y * S + x, k = i * 4
    guard inside(plumePoly, Double(x) + 0.5, Double(y) + 0.5) else { continue }
    let a = Double(crest[k + 3])
    let isTuft = inside(tuftPoly, Double(x) + 0.5, Double(y) + 0.5) && Double(crest[k + 1]) / max(Double(crest[k]), 1) >= 0.6
    if a > 250, !isTuft { known[i] = true; pr[i] = Double(crest[k]); pg[i] = Double(crest[k + 1]); pb[i] = Double(crest[k + 2]) }
    else { hole[i] = true }
} }
var cells: [Int] = []; for i in 0..<N where hole[i] { cells.append(i) }
for _ in 0..<600 { for i in cells {
    var r = 0.0, g = 0.0, b = 0.0, c = 0.0
    for j in [i - 1, i + 1, i - S, i + S] where known[j] || hole[j] { r += pr[j]; g += pg[j]; b += pb[j]; c += 1 }
    if c > 0 { pr[i] = r / c; pg[i] = g / c; pb[i] = b / c }
} }
// 윤곽 가장자리는 원래 알파(부드러운 가장자리), 메운 칸과 안쪽은 불투명
for y in 150..<620 { for x in 600..<1120 {
    let i = y * S + x, k = i * 4
    guard known[i] || hole[i] else { continue }
    let edge = Double(crest[k + 3]) / 255
    let alpha = hole[i] ? 1.0 : edge
    plume[k] = UInt8(min(255, pr[i] * alpha)); plume[k + 1] = UInt8(min(255, pg[i] * alpha)); plume[k + 2] = UInt8(min(255, pb[i] * alpha))
    plume[k + 3] = UInt8(alpha * 255)
} }
let tuftImg = image(tuft), plumeImg = image(plume), crestImg = image(crest)
save(tuftImg, "donor_tuft"); save(plumeImg, "donor_plume")

/// 깃털 하나 놓기: 원화의 밑동 `from`을 `to`로 옮기고, 밑동을 중심으로 `angle`도(시계 방향 +) 돌리고 `scale`배. `mirror`면 좌우 뒤집기.
struct Place { var img: CGImage; var from: P; var to: P; var angle: Double; var scale: Double; var mirror = false; var alpha = 1.0 }
func compose(_ items: [Place], _ name: String) {
    let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    for it in items {
        ctx.saveGState()
        // CG는 아래가 원점
        ctx.translateBy(x: it.to.x, y: Double(S) - it.to.y)
        ctx.rotate(by: -it.angle * .pi / 180)
        ctx.scaleBy(x: it.scale * (it.mirror ? -1 : 1), y: it.scale)
        ctx.translateBy(x: -it.from.x, y: -(Double(S) - it.from.y))
        ctx.setAlpha(it.alpha)
        ctx.draw(it.img, in: CGRect(x: 0, y: 0, width: S, height: S))
        ctx.restoreGState()
    }
    save(ctx.makeImage()!, name)
}

let pivot: P = (745, 588)          // 볏 밑동(앱의 볏 회전 중심)
let tuftBase: P = (726, 588)        // 노란 깃털의 뾰족한 밑동
let plumeBase: P = (724, 585)       // 주황 볏의 밑동

// MARK: 볏 — 단계마다 깃털 수와 크기
// 1단계: 원래 볏
compose([Place(img: crestImg, from: pivot, to: pivot, angle: 0, scale: 1)], "crest_1")
// 2단계: 볏을 조금 키우고, 양옆 뒤로 노란 깃털 둘
compose([
    Place(img: tuftImg, from: tuftBase, to: (700, 596), angle: -112, scale: 0.92, mirror: false),
    Place(img: tuftImg, from: tuftBase, to: (790, 596), angle: 18, scale: 0.88),
    Place(img: crestImg, from: pivot, to: pivot, angle: 0, scale: 1.1),
], "crest_2")
// 3단계: 왼쪽으로 기운 두 번째 주황 볏 + 노란 깃털 셋
compose([
    Place(img: plumeImg, from: plumeBase, to: (730, 600), angle: -58, scale: 0.88),
    Place(img: tuftImg, from: tuftBase, to: (690, 598), angle: -116, scale: 0.96),
    Place(img: tuftImg, from: tuftBase, to: (800, 598), angle: 22, scale: 0.92),
    Place(img: crestImg, from: pivot, to: pivot, angle: 0, scale: 1.16),
], "crest_3")
// 4단계: 세 갈래 주황 볏(왼쪽·오른쪽으로 기운 둘 + 가운데 큰 것) + 노란 깃털 넷
compose([
    Place(img: plumeImg, from: plumeBase, to: (728, 602), angle: -64, scale: 0.92),
    Place(img: plumeImg, from: plumeBase, to: (770, 602), angle: 38, scale: 0.8),
    Place(img: tuftImg, from: tuftBase, to: (680, 600), angle: -120, scale: 1.0),
    Place(img: tuftImg, from: tuftBase, to: (812, 600), angle: 26, scale: 0.96),
    Place(img: crestImg, from: pivot, to: pivot, angle: 0, scale: 1.2),
], "crest_4")

// MARK: 날개 — 날개 끝 아래로 노란 깃털이 비어져 나온다(날개 레이어에 함께 그려 같이 돈다)
let wingL = image(load("wing_left")), wingR = image(load("wing_right"))
func wings(_ stage: Int) {
    var left: [Place] = [], right: [Place] = []
    let feathers: [(scale: Double, spread: Double)] = switch stage {
    case 2: [(0.82, 0)]
    case 3: [(0.86, 0), (0.78, 20)]
    case 4: [(0.92, 0), (0.84, 20), (0.74, 40)]
    default: []
    }
    for f in feathers {
        // 밑동은 날개 밑(가려진 곳)에 두고 날개 바깥 아래 가장자리로 비어져 나오게 한다.
        left.append(Place(img: tuftImg, from: tuftBase, to: (428, 1080), angle: -53 + f.spread, scale: f.scale, mirror: true))
        right.append(Place(img: tuftImg, from: tuftBase, to: (1108, 1080), angle: 53 - f.spread, scale: f.scale))
    }
    compose(left + [Place(img: wingL, from: (0, 0), to: (0, 0), angle: 0, scale: 1)], "wing_left_\(stage)")
    compose(right + [Place(img: wingR, from: (0, 0), to: (0, 0), angle: 0, scale: 1)], "wing_right_\(stage)")
}
for stage in 1...4 { wings(stage) }

// MARK: 꼬리 — 몸 뒤, 아래 양옆으로 비어져 나온다(3단계 노란 깃털, 4단계 주황 깃털 + 노란 깃털)
compose([], "tail_1")
compose([], "tail_2")
compose([
    Place(img: tuftImg, from: tuftBase, to: (530, 1188), angle: -43, scale: 1.0, mirror: true),
    Place(img: tuftImg, from: tuftBase, to: (1006, 1188), angle: 43, scale: 1.0),
], "tail_3")
compose([
    Place(img: plumeImg, from: plumeBase, to: (560, 1176), angle: -56, scale: 0.56, mirror: true),
    Place(img: plumeImg, from: plumeBase, to: (976, 1176), angle: 56, scale: 0.56),
    Place(img: tuftImg, from: tuftBase, to: (530, 1194), angle: -36, scale: 1.0, mirror: true),
    Place(img: tuftImg, from: tuftBase, to: (1006, 1194), angle: 36, scale: 1.0),
], "tail_4")
print("ok")
