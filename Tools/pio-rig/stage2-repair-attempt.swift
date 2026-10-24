import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 사용법: fix <원래 레이어 폴더> <2단계 부품 폴더> <출력 폴더> <날개 깃 배율>
// 피오 2단계 날개·볏을 고친다. 원래(1단계) 날개·볏을 앞에 그대로 두고, 2단계 부품에서 "원래 윤곽 바깥으로 자라난 깃털"만 떼어 그 뒤에 붙인다.
// 떼어 낸 깃털은 원래 윤곽 안쪽 `tuck`px까지 포함해, 밑동과 가장자리가 늘 원래 날개·볏 밑에 숨는다(이음매·반투명 띠가 보이지 않는다).
// 원래 레이어와 마스터는 바꾸지 않는다. 몸 색 띠(날개 뿌리)와 볏 밑의 머리 피부 조각은 쓰지 않는다.
let a = CommandLine.arguments
let orig = URL(fileURLWithPath: a[1]), parts = URL(fileURLWithPath: a[2]), out = URL(fileURLWithPath: a[3])
let tipScale = Double(a.count > 4 ? a[4] : "1") ?? 1
let W = 1536, N = W * W
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func load(_ url: URL) -> [UInt8] {
    let s = CGImageSourceCreateWithURL(url as CFURL, nil)!, i = CGImageSourceCreateImageAtIndex(s, 0, nil)!
    var d = [UInt8](repeating: 0, count: N * 4)
    CGContext(data: &d, width: W, height: W, bitsPerComponent: 8, bytesPerRow: W * 4, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.draw(i, in: CGRect(x: 0, y: 0, width: W, height: W))
    return d
}
func image(_ px: [UInt8]) -> CGImage {
    var p = px
    return CGContext(data: &p, width: W, height: W, bitsPerComponent: 8, bytesPerRow: W * 4, space: space,
                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
}
func save(_ img: CGImage, _ name: String) {
    let d = CGImageDestinationCreateWithURL(out.appendingPathComponent(name + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
/// 알파가 0.5 넘는 칸을 `r`px 깎은 가리개(원래 윤곽 안쪽 깊숙한 곳).
func eroded(_ px: [UInt8], _ r: Int) -> [Bool] {
    var solid = [Bool](repeating: false, count: N)
    for i in 0..<N { solid[i] = px[i * 4 + 3] > 128 }
    // 바깥(=solid 아님)을 r만큼 넓힌 것의 반대
    var outside = [Bool](repeating: false, count: N)
    for y in 0..<W { for x in 0..<W where !solid[y * W + x] {
        // 경계 근처만 넓힌다(속도)
        var near = false
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let xx = x + dx, yy = y + dy
            if xx >= 0, xx < W, yy >= 0, yy < W, solid[yy * W + xx] { near = true; break }
        }
        guard near else { continue }
        for dy in -r...r { for dx in -r...r where dx * dx + dy * dy <= r * r {
            let xx = x + dx, yy = y + dy
            if xx >= 0, xx < W, yy >= 0, yy < W { outside[yy * W + xx] = true }
        } }
    } }
    return (0..<N).map { solid[$0] && !outside[$0] }
}

/// 2단계 부품에서 원래 윤곽 깊은 안쪽(`deep`)을 뺀 나머지 중 `keep`이 참인 칸만 남긴다. 잘린 경계는 원래 윤곽 안에 숨는다.
func sat(_ px: [UInt8], _ i: Int) -> Double {
    let r = Double(px[i * 4]), g = Double(px[i * 4 + 1]), b = Double(px[i * 4 + 2]), mx = max(r, g, b)
    return mx > 0 ? (mx - min(r, g, b)) / mx : 0
}
func growth(_ part: [UInt8], deep: [Bool], keep: (Int, Int, Int) -> Bool) -> [UInt8] {
    var o = [UInt8](repeating: 0, count: N * 4)
    for y in 0..<W { for x in 0..<W {
        let i = y * W + x
        guard part[i * 4 + 3] > 0, !deep[i], keep(x, y, i) else { continue }
        for c in 0..<4 { o[i * 4 + c] = part[i * 4 + c] }
    } }
    return o
}

/// 알파가 있는 칸들의 연결 덩어리 가운데 `minimum`픽셀보다 작은 것을 지운다(가장자리 부스러기).
func dropSpecks(_ px: [UInt8], minimum: Int) -> [UInt8] {
    var o = px, seen = [Bool](repeating: false, count: N)
    for start in 0..<N where px[start * 4 + 3] > 0 && !seen[start] {
        var stack = [start], comp: [Int] = []; seen[start] = true
        while let i = stack.popLast() {
            comp.append(i)
            let x = i % W, y = i / W
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)] {
                let xx = x + dx, yy = y + dy
                guard xx >= 0, xx < W, yy >= 0, yy < W else { continue }
                let j = yy * W + xx
                if !seen[j], px[j * 4 + 3] > 0 { seen[j] = true; stack.append(j) }
            }
        }
        if comp.count < minimum { for i in comp { for c in 0..<4 { o[i * 4 + c] = 0 } } }
    }
    return o
}

/// 뒤에 붙일 깃털과 원래 부위를 합친다: 깃털(뒤, `pivot` 둘레로 `scale`배) → 원래 부위(앞).
func compose(back: [UInt8], front: [UInt8], pivot: (Double, Double), scale: Double, name: String) {
    let ctx = CGContext(data: nil, width: W, height: W, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.saveGState()
    let px = pivot.0, py = Double(W) - pivot.1
    ctx.translateBy(x: px, y: py); ctx.scaleBy(x: scale, y: scale); ctx.translateBy(x: -px, y: -py)
    ctx.draw(image(back), in: CGRect(x: 0, y: 0, width: W, height: W))
    ctx.restoreGState()
    ctx.draw(image(front), in: CGRect(x: 0, y: 0, width: W, height: W))
    save(ctx.makeImage()!, name)
}

let tuck = 26
// 날개: 원래 날개 윤곽 안쪽 26px보다 깊은 곳은 원래 날개가 덮으므로 2단계 픽셀을 쓰지 않는다.
// 몸 쪽 뿌리 띠(왼쪽 x>430, 오른쪽 x<1106)는 버린다.
let wl = load(orig.appendingPathComponent("wing_left.png")), wr = load(orig.appendingPathComponent("wing_right.png"))
let nl = load(parts.appendingPathComponent("pio_stage2_wing_left_full.png")), nr = load(parts.appendingPathComponent("pio_stage2_wing_right_full.png"))
// 새로 자란 주황 깃 끝만(채도 높은 픽셀). 크림색 날개 본체의 가장자리는 원래 날개와 겹쳐 테두리가 두 겹으로 보이므로 쓰지 않는다.
let tipsL = dropSpecks(growth(nl, deep: eroded(wl, tuck)) { x, y, i in x < 430 && y > 960 && sat(nl, i) > 0.5 }, minimum: 400)
let tipsR = dropSpecks(growth(nr, deep: eroded(wr, tuck)) { x, y, i in x > 1106 && y > 960 && sat(nr, i) > 0.5 }, minimum: 400)
// 배율은 날개 가운데쯤(뿌리 안쪽)을 중심으로: 깃 끝만 바깥으로 자란다.
compose(back: tipsL, front: wl, pivot: (430, 1030), scale: tipScale, name: "wing_left_2")
compose(back: tipsR, front: wr, pivot: (1106, 1030), scale: tipScale, name: "wing_right_2")
save(image(tipsL), "debug_tips_left")

// 볏: 원래 볏 윤곽 안쪽 18px보다 깊은 곳은 원래 볏이 덮는다. 머리 피부 조각(밑동 아래 y>578)은 버린다.
let cr = load(orig.appendingPathComponent("crest.png")), nc = load(parts.appendingPathComponent("pio_stage2_crest_full.png"))
// 새로 자란 깃은 볏 오른쪽의 노랑·주황 깃 둘뿐이다(x>890). 큰 주황 볏과 왼쪽 깃은 원래 것과 어긋나 두 겹으로 보이므로 쓰지 않는다.
// 머리 피부 조각은 채도가 낮아(크림색) 채도로 걸러 낸다(가로로 자르지 않는다).
// 새로 자란 깃만: 원래 볏 오른쪽(x>890). 머리(몸 실루엣) 안쪽에 들어간 픽셀은 버린다 → 밑동은 머리 뒤에 숨고 피부 조각이 남지 않는다.
// 큰 주황 볏과 겹치는 위쪽(y<470)에서는 금빛 깃(초록/빨강 > 0.6)만 남겨 새 볏의 윤곽선이 끼지 않게 한다.
let bodyPx = load(orig.appendingPathComponent("body.png"))
// 머리 안쪽으로 들어간 깊이: 경계에서 0, 18px 안쪽에서 1. 밑동은 머리 위에 부드럽게 사라진다(칼로 자르지 않는다).
let depthMasks = [4, 9, 14, 18].map { eroded(bodyPx, $0) }
var addC = growth(nc, deep: eroded(cr, 18)) { x, y, i in
    let r = Double(nc[i * 4]), g = Double(nc[i * 4 + 1])
    // 아래쪽 작은 깃(y>532)은 밑동 원화가 없어 기울면 떠 보이므로 쓰지 않는다.
    return x > 890 && y > 380 && y < 532 && (y >= 470 || g / max(r, 1) > 0.6) && !depthMasks[3][i]
}
for i in 0..<N where bodyPx[i * 4 + 3] > 128 && addC[i * 4 + 3] > 0 {
    let level = depthMasks.prefix(3).filter { $0[i] }.count  // 0…3
    let keep = [0.85, 0.55, 0.28, 0.1][level]
    for c in 0..<4 { addC[i * 4 + c] = UInt8(Double(addC[i * 4 + c]) * keep) }
}
addC = dropSpecks(addC, minimum: 400)
compose(back: addC, front: cr, pivot: (745, 588), scale: 1, name: "crest_2")
save(image(addC), "debug_crest_add")
print("ok")
