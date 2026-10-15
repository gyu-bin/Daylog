import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 사용법: rigtool <master.png> <출력 폴더>
// 피오 마스터 한 장에서 부위 레이어를 떼어 낸다. 모든 레이어는 마스터와 같은 1536 캔버스·같은 좌표.
// - 앞에 있는 부위(날개·볏·눈): 마스터 픽셀 그대로 + 부드러운 가장자리. 그 밑의 몸은 둘레의 음영에서 라플라스 방정식으로 메우고 결을 더한다.
// - 뒤에 있는 부위(발): 몸 실루엣 바깥의 주황 픽셀.
// - 몸 실루엣: 중심에서 본 극좌표 반지름이 매끄러운 달걀꼴이라, 부위에 가려진 각도는 보이는 윤곽에서 이어 그린다.

let args = CommandLine.arguments
let out = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// MARK: 읽기·쓰기

let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let W = image.width, H = image.height, N = W * H
var raw = [UInt8](repeating: 0, count: N * 4)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
CGContext(data: &raw, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.draw(image, in: CGRect(x: 0, y: 0, width: W, height: H))
// 곧은(premultiply 안 한) 색과 알파, 0…1
var R = [Float](repeating: 0, count: N), G = R, B = R, A = R
for i in 0..<N {
    let a = Float(raw[i * 4 + 3]) / 255
    A[i] = a
    if a > 0 { R[i] = Float(raw[i * 4]) / 255 / a; G[i] = Float(raw[i * 4 + 1]) / 255 / a; B[i] = Float(raw[i * 4 + 2]) / 255 / a }
}

func save(_ name: String, r: [Float], g: [Float], b: [Float], a: [Float]) {
    var px = [UInt8](repeating: 0, count: N * 4)
    for i in 0..<N {
        let al = max(0, min(1, a[i]))
        px[i * 4] = UInt8(max(0, min(1, r[i])) * al * 255 + 0.5)
        px[i * 4 + 1] = UInt8(max(0, min(1, g[i])) * al * 255 + 0.5)
        px[i * 4 + 2] = UInt8(max(0, min(1, b[i])) * al * 255 + 0.5)
        px[i * 4 + 3] = UInt8(al * 255 + 0.5)
    }
    let ctx = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let dest = CGImageDestinationCreateWithURL(out.appendingPathComponent(name + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: 다각형·가리개

typealias P = (x: Double, y: Double)
func parse(_ s: String) -> [P] { s.split(separator: ";").map { let v = $0.split(separator: ","); return (Double(v[0])!, Double(v[1])!) } }
func mirror(_ p: [P]) -> [P] { p.map { (Double(W) - $0.x, $0.y) } }
func inside(_ poly: [P], _ x: Double, _ y: Double) -> Bool {
    var c = false; var j = poly.count - 1
    for i in 0..<poly.count {
        let a = poly[i], b = poly[j]
        if (a.y > y) != (b.y > y), x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x { c.toggle() }
        j = i
    }
    return c
}
func polyMask(_ poly: [P]) -> [Float] {
    var m = [Float](repeating: 0, count: N)
    let minX = max(0, Int(poly.map(\.x).min()!) - 2), maxX = min(W - 1, Int(poly.map(\.x).max()!) + 2)
    let minY = max(0, Int(poly.map(\.y).min()!) - 2), maxY = min(H - 1, Int(poly.map(\.y).max()!) + 2)
    for y in minY...maxY { for x in minX...maxX {
        // 4점 표본으로 가장자리를 부드럽게
        var c = 0
        for (dx, dy) in [(0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)] where inside(poly, Double(x) + dx, Double(y) + dy) { c += 1 }
        m[y * W + x] = Float(c) / 4
    } }
    return m
}
func blur(_ m: [Float], radius: Int) -> [Float] {
    var t = m, o = m
    for y in 0..<H { var s: Float = 0
        for x in -radius...radius { s += m[y * W + max(0, min(W - 1, x))] }
        for x in 0..<W { t[y * W + x] = s / Float(2 * radius + 1)
            s += m[y * W + min(W - 1, x + radius + 1)] - m[y * W + max(0, x - radius)] } }
    for x in 0..<W { var s: Float = 0
        for y in -radius...radius { s += t[max(0, min(H - 1, y)) * W + x] }
        for y in 0..<H { o[y * W + x] = s / Float(2 * radius + 1)
            s += t[min(H - 1, y + radius + 1) * W + x] - t[max(0, y - radius) * W + x] } }
    return o
}
func dilate(_ m: [Float], radius: Int) -> [Float] {
    var o = m
    for y in 0..<H { for x in 0..<W where m[y * W + x] > 0.5 {
        for dy in -radius...radius { for dx in -radius...radius where dx * dx + dy * dy <= radius * radius {
            let xx = x + dx, yy = y + dy
            if xx >= 0, xx < W, yy >= 0, yy < H { o[yy * W + xx] = 1 }
        } }
    } }
    return o
}
func sat(_ i: Int) -> Float { let mx = max(R[i], G[i], B[i]), mn = min(R[i], G[i], B[i]); return mx > 0 ? (mx - mn) / mx : 0 }
func luma(_ i: Int) -> Float { 0.3 * R[i] + 0.59 * G[i] + 0.11 * B[i] }

// 왼쪽 날개(원화 좌표) — 확대 그림에서 땄다. 오른쪽은 좌우 대칭.
let wingL = parse("416.7,898.3;446.7,903.3;470.0,916.7;486.7,936.7;498.3,960.0;506.0,986.7;510.0,1013.3;510.7,1043.3;507.3,1073.3;500.7,1100.0;490.7,1123.3;479.0,1141.7;464.0,1153.3;446.7,1160.0;430.0,1156.7;416.7,1146.7;407.3,1136.7;393.3,1134.0;373.3,1127.3;356.7,1110.7;346.7,1087.3;343.3,1074.0;333.3,1070.7;320.0,1057.3;310.7,1036.7;308.7,1013.3;314.0,990.0;326.0,963.3;343.3,936.7;366.7,916.7;390.0,903.3")
// 날개 안쪽 가장자리를 2px 넉넉히(몸 쪽으로) — 가장자리 픽셀이 몸에 남지 않게
let wingLPad = wingL.map { (p: P) -> P in p.x > 470 ? (p.x + 2.5, p.y) : p }
let wingR = mirror(wingLPad)
// 볏과 깃털(머리 위). 아래쪽 가장자리는 깃털의 밑선을 따른다.
let crest = parse("500,140;1110,140;1110,470;980,536;953.3,564;920,571;876.7,576;853.3,586.3;786.7,591.5;720,590;670,595;620,584.5;586.7,577;553.3,538;500,480")

func shifted(_ p: [P], _ dy: Double) -> [P] {
    // 아래쪽 가장자리(y > 560)만 내린다
    p.map { $0.y > 560 ? ($0.x, $0.y + dy) : $0 }
}
var mWingL = polyMask(wingLPad), mWingR = polyMask(wingR), mCrest = polyMask(shifted(crest, 12))
let mCrestLayer = polyMask(shifted(crest, 2))
for i in 0..<N { mWingL[i] *= A[i] > 0.01 ? 1 : 0; mWingR[i] *= A[i] > 0.01 ? 1 : 0; mCrest[i] *= A[i] > 0.01 ? 1 : 0 }

// 눈: 눈 상자 안의 어두운 픽셀이 차지하는 타원(안의 흰 반사광까지)을 조금 넓힌 것
var mEye = [Float](repeating: 0, count: N)
var eyeEllipses: [(Double, Double, Double, Double)] = []
for (x0, y0, x1, y1) in [(545, 770, 690, 920), (846, 770, 991, 920)] {
    var minX = x1, maxX = x0, minY = y1, maxY = y0
    for y in y0...y1 { for x in x0...x1 { let i = y * W + x
        if A[i] > 0.5, luma(i) < 0.45 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } } }
    let ex = Double(minX + maxX + 1) / 2, ey = Double(minY + maxY + 1) / 2
    // 눈 둘레의 밝은 테두리까지 담는다(12px)
    let rx = Double(maxX - minX + 1) / 2 + 12, ry = Double(maxY - minY + 1) / 2 + 12
    eyeEllipses.append((ex, ey, rx - 12, ry - 12))
    for y in (y0 - 10)...(y1 + 10) { for x in (x0 - 10)...(x1 + 10) {
        let dx = (Double(x) + 0.5 - ex) / rx, dy = (Double(y) + 0.5 - ey) / ry
        let d = (dx * dx + dy * dy).squareRoot()
        mEye[y * W + x] = max(mEye[y * W + x], Float(max(0, min(1, (1 - d) * min(rx, ry) + 0.5))))
    } }
}
print("eyes", eyeEllipses)
// 발: 아래쪽의 진한 주황
var mFootRaw = [Float](repeating: 0, count: N)
for y in 1180..<H { for x in 0..<W { let i = y * W + x
    if A[i] > 0.02, sat(i) > 0.70, R[i] > 0.6, G[i] < 0.63 { mFootRaw[i] = 1 }
} }
let mFoot = dilate(mFootRaw, radius: 2)

// MARK: 몸 실루엣(극좌표)

// 부위가 바깥 경계를 이루는 각도를 넉넉히 찾으려고 가리개를 넓혀 쓴다
var occluderRaw = [Float](repeating: 0, count: N)
for i in 0..<N { occluderRaw[i] = (mWingL[i] > 0 || mWingR[i] > 0 || mCrest[i] > 0 || mFoot[i] > 0) ? 1 : 0 }
let occluder = dilate(occluderRaw, radius: 8)

let cx = 768.0, cy = 930.0
let steps = 1440
var radius = [Double](repeating: 0, count: steps), known = [Bool](repeating: false, count: steps)
var footLimit = [Double](repeating: .infinity, count: steps)
for k in 0..<steps {
    let t = Double(k) / Double(steps) * 2 * .pi, dx = cos(t), dy = sin(t)
    // 바깥 경계(밖에서 안으로 처음 불투명)
    var r = 900.0
    while r > 10 {
        let x = Int(cx + dx * r), y = Int(cy + dy * r)
        if x >= 0, x < W, y >= 0, y < H, A[y * W + x] > 0.5 { break }
        r -= 0.5
    }
    let x = Int(cx + dx * r), y = Int(cy + dy * r), i = y * W + x
    radius[k] = r
    // 안에서 밖으로 처음 만나는 발 색: 발 위로 보이는 몸의 밑선
    var rin = 60.0
    while rin < r {
        let fx = Int(cx + dx * rin), fy = Int(cy + dy * rin)
        if mFootRaw[fy * W + fx] > 0 { break }
        rin += 0.5
    }
    footLimit[k] = rin < r - 2 ? rin : .infinity
    // 바깥 경계가 날개·볏·발이면 가려진 각도
    known[k] = !(occluder[i] > 0) && footLimit[k] == .infinity
}
let radius0 = radius
// 가려진 구간: 양쪽의 보이는 반지름과 기울기로 3차 에르미트 보간
func at(_ k: Int) -> Int { (k % steps + steps) % steps }
var k = 0
while k < steps {
    if known[k] { k += 1; continue }
    var a = k; while !known[at(a - 1)] { a -= 1 }
    var b = k; while !known[at(b + 1)] { b += 1 }
    let r0 = radius[at(a - 1)], r1 = radius[at(b + 1)]
    let s0 = (radius[at(a - 1)] - radius[at(a - 9)]) / 8, s1 = (radius[at(b + 9)] - radius[at(b + 1)]) / 8
    let n = Double(b - a + 2)
    for j in a...b {
        let t = Double(j - a + 1) / n
        let h00 = 2 * t * t * t - 3 * t * t + 1, h10 = t * t * t - 2 * t * t + t, h01 = -2 * t * t * t + 3 * t * t, h11 = t * t * t - t * t
        let v = h00 * r0 + h10 * n * s0 + h01 * r1 + h11 * n * s1
        radius[at(j)] = min(max(v, min(r0, r1) - 25), max(r0, r1) + 25)
    }
    k = b + 1
}
// 발이 있는 각도: 매끄럽게 이은 밑선이 발 위로 보이는 실제 밑선보다 아래로 내려가지 않게
for k in 0..<steps where footLimit[k] < .infinity { radius[k] = min(radius[k], footLimit[k]) }
// 살짝 고르게(잔물결 제거)
var smooth = radius
for k in 0..<steps { var s = 0.0; for j in -3...3 { s += radius[at(k + j)] }; smooth[k] = s / 7 }
var silhouette = [Float](repeating: 0, count: N)
for y in 0..<H { for x in 0..<W {
    let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
    let d = (dx * dx + dy * dy).squareRoot()
    var t = atan2(dy, dx); if t < 0 { t += 2 * .pi }
    let f = t / (2 * .pi) * Double(steps); let k0 = Int(f) % steps, k1 = (k0 + 1) % steps, w = f - floor(f)
    let r = smooth[k0] * (1 - w) + smooth[k1] * w
    silhouette[y * W + x] = Float(max(0, min(1, r - d + 0.5)))
} }

// MARK: 몸 밑 메우기(라플라스 + 결)

// 앞 부위 밑(날개·볏·눈)이면서 몸 안쪽인 곳이 모르는 칸
var front = [Float](repeating: 0, count: N)
// 날개가 몸에 드리운 접촉 그림자 띠(날개 둘레 몸 쪽 12px): 몸은 깨끗한 피부로 메우고, 그림자는 날개에 붙은 레이어로 뺀다
let bandL = dilate(mWingL, radius: 26), bandR = dilate(mWingR, radius: 26)
// 띠 바깥쪽에서는 메운 색이 원래 피부로 서서히 넘어가게 섞는다(경계선이 생기지 않게): 날개에서 12px까지는 메운 색만,
// 12~26px은 원래 피부 쪽으로 점점. 무게는 넓힌 가리개 세 겹을 흐려 만든다.
let wingBoth = (0..<N).map { max(mWingL[$0], mWingR[$0]) }
let d12 = dilate(wingBoth, radius: 12), d19 = dilate(wingBoth, radius: 19), d26 = dilate(wingBoth, radius: 26)
let keepFill = blur((0..<N).map { d12[$0] * 0.34 + d19[$0] * 0.33 + d26[$0] * 0.33 }, radius: 3)
for i in 0..<N { front[i] = max(mWingL[i], mWingR[i], mCrest[i], mEye[i], silhouette[i] > 0.99 ? max(bandL[i], bandR[i]) : 0) }
var unknown = [Bool](repeating: false, count: N), solid = [Bool](repeating: false, count: N)
for i in 0..<N {
    if front[i] > 0, silhouette[i] > 0 { unknown[i] = true }
    else if silhouette[i] > 0.99, A[i] > 0.97, mFoot[i] == 0 { solid[i] = true }
}
var cells: [Int] = []
for i in 0..<N where unknown[i] { cells.append(i) }
// 처음 값: 가장 가까운 아는 픽셀 쪽으로 퍼뜨린 값(빨리 수렴하게)
for ch in [0, 1, 2] {
    var v = ch == 0 ? R : (ch == 1 ? G : B)
    var have = solid
    var frontier = cells
    for _ in 0..<400 where !frontier.isEmpty {
        var next: [Int] = []
        var newly: [(Int, Float)] = []
        for i in frontier where !have[i] {
            var s: Float = 0, c: Float = 0
            for j in [i - 1, i + 1, i - W, i + W] where j >= 0 && j < N && have[j] { s += v[j]; c += 1 }
            if c > 0 { newly.append((i, s / c)) } else { next.append(i) }
        }
        for (i, val) in newly { v[i] = val; have[i] = true }
        frontier = next
    }
    // SOR 반복: 모르는 칸 = 몸 안쪽 이웃(아는 칸·모르는 칸)의 평균. 몸 바깥 이웃은 쓰지 않는다(경계에서 기울기 0).
    let omega: Float = 1.92
    for _ in 0..<2500 {
        for i in cells {
            var s: Float = 0, c: Float = 0
            for j in [i - 1, i + 1, i - W, i + W] where j >= 0 && j < N && (unknown[j] || solid[j]) { s += v[j]; c += 1 }
            if c > 0 { v[i] += omega * (s / c - v[i]) }
        }
    }
    if ch == 0 { R = v } else if ch == 1 { G = v } else { B = v }
}
// 몸의 잔결(마스터에서 고운 무늬의 세기)을 재서 메운 곳에 같은 세기로 입힌다.
let blurred = (blur(R, radius: 3), blur(G, radius: 3), blur(B, radius: 3))
var sum: Float = 0, cnt: Float = 0
for i in stride(from: 0, to: N, by: 7) where solid[i] && !unknown[i] { let d = R[i] - blurred.0[i]; sum += d * d; cnt += 1 }
let grain = (sum / max(cnt, 1)).squareRoot()
var rng = SystemRandomNumberGenerator()
var noise = [Float](repeating: 0, count: N)
for i in cells { noise[i] = Float.random(in: -1...1, using: &rng) }
noise = blur(noise, radius: 3)
var nsum: Float = 0; for i in cells { nsum += noise[i] * noise[i] }
let nstd = (nsum / Float(max(cells.count, 1))).squareRoot()
// 날개·볏 밑은 아래에서 몸 가운데 쪽(좌우 260px 안쪽)의 실제 피부 결을 옮겨 붙인다(난수 결은 얼룩져 보인다).
// 눈 밑: 난수 결 대신 바로 위 이마 피부의 실제 결(고주파)을 옮겨 붙인다(매끈한 원판처럼 보이지 않게).
var R0b = [Float](repeating: 0, count: N), G0b = R0b, B0b = R0b
for i in 0..<N { let a = Float(raw[i * 4 + 3]) / 255
    if a > 0 { R0b[i] = Float(raw[i * 4]) / 255 / a; G0b[i] = Float(raw[i * 4 + 1]) / 255 / a; B0b[i] = Float(raw[i * 4 + 2]) / 255 / a } }
let hp = (blur(R0b, radius: 3), blur(G0b, radius: 3), blur(B0b, radius: 3))
for i in cells {
    let x = i % W
    // 날개·볏 밑: 배의 매끈한 피부(640~900, 1000~1180)를 거울 반복으로 깐 결. 눈 밑: 바로 위 이마.
    let y = i / W
    func mirrorTile(_ v: Int, _ n: Int) -> Int { let m = v % (2 * n); return m < n ? m : 2 * n - 1 - m }
    let donor = mEye[i] > 0 ? i - 150 * W : (1000 + mirrorTile(y, 180)) * W + 640 + mirrorTile(x, 260)
    guard donor >= 0, donor < N, A[donor] > 0.99 else { continue }
    R[i] += R0b[donor] - hp.0[donor]; G[i] += G0b[donor] - hp.1[donor]; B[i] += B0b[donor] - hp.2[donor]
}
print("grain \(grain) unknown \(cells.count)")

// MARK: 레이어

let master = (r: (0..<N).map { Float(raw[$0 * 4]) }, a: A)  // 비교용
var zero = [Float](repeating: 0, count: N)
func layer(_ name: String, mask: [Float]) {
    var a = zero
    for i in 0..<N { a[i] = A[i] * mask[i] }
    save(name, r: R0, g: G0, b: B0, a: a)
}
// 부위는 마스터의 원래 색을 쓴다(메운 값이 아니라)
var R0 = [Float](repeating: 0, count: N), G0 = R0, B0 = R0
for i in 0..<N { let a = Float(raw[i * 4 + 3]) / 255
    if a > 0 { R0[i] = Float(raw[i * 4]) / 255 / a; G0[i] = Float(raw[i * 4 + 1]) / 255 / a; B0[i] = Float(raw[i * 4 + 2]) / 255 / a } }

// 날개는 몸 바깥쪽으로만 5px 넓혀 가장자리의 흐린 윤곽 픽셀까지 담는다(몸 쪽 경계는 그대로)
let grownL = dilate(mWingL, radius: 5), grownR = dilate(mWingR, radius: 5)
for i in 0..<N where silhouette[i] < 0.01 && A[i] > 0 {
    if grownL[i] > 0 { mWingL[i] = 1 }
    if grownR[i] > 0 { mWingR[i] = 1 }
}
let softWingL = blur(mWingL, radius: 1), softWingR = blur(mWingR, radius: 1), softCrest = blur(mCrestLayer, radius: 2)
let softEye = mEye
layer("wing_left", mask: softWingL)
layer("wing_right", mask: softWingR)
layer("crest", mask: softCrest)
layer("eyes", mask: softEye)
// 발: 몸 실루엣 바깥(몸이 앞에 있다)
// 발: 몸 실루엣 아래쪽(몸이 앞에 있다)에 있는 것은 날개가 아니면 모두 발이다(밝은 반사광까지 빠짐없이).
var footL = zero, footR = zero
// 날개 끝의 가장자리 픽셀이 발에 섞이지 않게 날개 둘레 8px은 발에서 뺀다(날개를 들면 점으로 남는다)
let wingZone = dilate((0..<N).map { max(mWingL[$0], mWingR[$0]) }, radius: 8)
for y in 1150..<H { for x in 0..<W { let i = y * W + x
    guard A[i] > 0, wingZone[i] == 0 else { continue }
    let m = 1 - silhouette[i]
    if x < 768 { footL[i] = m } else { footR[i] = m }
} }
layer("foot_left", mask: footL)
layer("foot_right", mask: footR)
// 몸: 앞 부위 밑은 메운 색, 그 밖은 마스터 그대로. 알파는 부위·발 자리에서는 실루엣, 그 밖은 마스터.
var bodyA = zero, bodyR = R0, bodyG = G0, bodyB = B0
for i in 0..<N {
    let partHere = max(front[i], mFoot[i])
    if unknown[i] {
        // 날개 둘레 띠에서는 원래 피부와 섞는다(앞 부위 자체 밑은 메운 색 그대로)
        let w = (mWingL[i] > 0 || mWingR[i] > 0 || mCrest[i] > 0 || mEye[i] > 0) ? 1 : min(1, keepFill[i] * 1.5)
        bodyR[i] = R[i] * w + R0[i] * (1 - w); bodyG[i] = G[i] * w + G0[i] * (1 - w); bodyB[i] = B[i] * w + B0[i] * (1 - w)
    }
    bodyA[i] = (partHere > 0 || occluder[i] > 0) ? min(silhouette[i], max(A[i], unknown[i] ? 1 : 0)) : A[i]
    // 부위의 부드러운 가장자리에서는 메운 색과 원래 색을 섞어 이음매를 없앤다
    let soft = max(softWingL[i], softWingR[i], softCrest[i], softEye[i])
    if !unknown[i], soft > 0, silhouette[i] > 0 { bodyR[i] = R0[i]; bodyG[i] = G0[i]; bodyB[i] = B0[i] }
}
save("body", r: bodyR, g: bodyG, b: bodyB, a: bodyA)
for (name, band, wing) in [("wing_left_shadow", bandL, mWingL), ("wing_right_shadow", bandR, mWingR)] {
    var sa = zero
    for i in 0..<N where band[i] > 0 && wing[i] == 0 && silhouette[i] > 0.99 && unknown[i] {
        let master = 0.3 * R0[i] + 0.59 * G0[i] + 0.11 * B0[i], fill = 0.3 * bodyR[i] + 0.59 * bodyG[i] + 0.11 * bodyB[i]
        sa[i] = max(0, min(0.6, 1 - master / max(fill, 0.01)))
    }
    // 띠의 바깥쪽 끝에서 0으로 부드럽게
    save(name, r: zero, g: zero, b: zero, a: blur(sa, radius: 1))
}
// 확인용: 실루엣(빨강 반투명)과 바깥 경계에서 보이는 각도(초록)·가려진 각도(보라)
var dbR = zero, dbG = zero, dbB = zero, dbA = zero
for i in 0..<N where silhouette[i] > 0 { dbR[i] = 1; dbA[i] = silhouette[i] * 0.35 }
for k in 0..<steps {
    let t = Double(k) / Double(steps) * 2 * .pi
    let x = Int(cx + cos(t) * radius0[k]), y = Int(cy + sin(t) * radius0[k])
    for dy in -2...2 { for dx in -2...2 { let xx = x + dx, yy = y + dy; guard xx >= 0, xx < W, yy >= 0, yy < H else { continue }
        let i = yy * W + xx; dbA[i] = 1; dbR[i] = known[k] ? 0 : 1; dbG[i] = known[k] ? 1 : 0; dbB[i] = known[k] ? 0 : 1 } }
}
save("debug_silhouette", r: dbR, g: dbG, b: dbB, a: dbA)
print("known angles \(known.filter { $0 }.count)/\(steps)")
