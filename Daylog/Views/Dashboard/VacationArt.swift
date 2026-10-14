import Accelerate
import CoreGraphics
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 휴가 화면의 그림 조각과 그 자리. 그림은 `Assets.xcassets/Vacation`에 있고, 받은 벡터 원본(`Tools/vacation-art`)을
/// `Tools/vacation-layers.swift`가 조각별로 나눠 그린 것이다. 아래의 자리는 그 도구가 출력한 값이다(그림을 바꾸면 함께 고친다).
///
/// 단위는 세 가지다: 해먹·새싹이는 1024 정사각형(포즈), 야자나무는 1024×1600, 배경은 2400 정사각형. 모두 위에서 아래로 센다.
enum VacationArt {
    /// 그림 한 조각: 에셋 이름, 원본 캔버스에서의 자리, 돌리거나 늘일 때의 기준점(없으면 가운데).
    struct Piece: Equatable, Sendable {
        let asset: String
        let rect: CGRect
        var pivot: CGPoint?

        init(_ asset: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, pivot: CGPoint? = nil) {
            self.asset = asset
            rect = CGRect(x: x, y: y, width: width, height: height)
            self.pivot = pivot
        }

        /// 기준점이 조각 안에서 어디인지(0…1).
        var anchor: CGPoint {
            guard let pivot else { return CGPoint(x: 0.5, y: 0.5) }
            return CGPoint(x: (pivot.x - rect.minX) / rect.width, y: (pivot.y - rect.minY) / rect.height)
        }
    }

    // MARK: - 해먹과 새싹이(포즈 단위)

    static let canvas: CGFloat = 1024
    /// 화면에서 자리를 잡아 주는 띠: 포즈 정사각형 가운데 해먹이 있는 높이(고리 끝에서 해먹 바닥까지).
    static let slotTop: CGFloat = 143
    static let slotHeight: CGFloat = 676
    /// 해먹 줄이 나무에 묶인 높이. 해먹은 이 선을 붙잡힌 채로 흔들린다.
    static let hookLine: CGFloat = 253
    /// 모래가 시작되는 높이(야자나무의 밑동이 여기에 묻힌다).
    static let sandLine: CGFloat = 742

    static let hammockBack = Piece("vacation_hammock_back", 54, 142, 918, 616)
    static let hammockFront = Piece("vacation_hammock_front", 92, 272, 842, 544)
    static let body = Piece("vacation_saessagi_body", 252, 354, 516, 402)
    /// 잎은 줄기 밑동을 중심으로 흔들린다.
    static let leaf = Piece("vacation_saessagi_leaf", 480, 172, 370, 224, pivot: CGPoint(x: 630, y: 382))
    static let sunglasses = Piece("vacation_saessagi_sunglasses", 480, 492, 214, 100)
    /// 잔은 잔의 입구 가운데(원본에서 잔을 놓은 기준점)를 중심으로 기울인다.
    static let drink = Piece("vacation_drink", 286, 418, 126, 268, pivot: CGPoint(x: 325, y: 565))
    static let handRest = Piece("vacation_hand_rest", 352, 588, 122, 86)
    static let armSip = Piece("vacation_arm_sip", 456, 546, 126, 132, pivot: CGPoint(x: 483, y: 651))
    static let armAdjust = Piece("vacation_arm_adjust", 656, 502, 134, 166, pivot: CGPoint(x: 755, y: 639))
    /// 숨쉬기의 기준: 해먹에 닿은 몸의 아래쪽.
    static let breathPivot = CGPoint(x: 500, y: 750)

    /// 마실 때 잔이 가는 자리: 쉬는 자리에서의 이동(포즈 단위)과 기울기(도). 받은 "sip" 포즈의 값이다.
    static let sipOffset = CGSize(width: 215, height: -19)
    static let sipTilt: Double = 9
    /// 그때 쉬던 손이 잔을 따라가는 거리(쉬는 손의 자리 → 마시는 팔의 손 자리).
    static let sipHandOffset = CGSize(width: 138, height: -47)

    // MARK: - 야자나무(1024×1600 단위)

    enum PalmSide: CaseIterable, Sendable {
        case left, right
    }

    /// 야자나무 그림이 포즈 단위에서 차지하는 배율: 나무 그림 1이 포즈의 0.39.
    static let palmScale: CGFloat = 0.39
    /// 나무 캔버스의 왼쪽 위가 포즈 단위에서 어디인지. 나무 꼭대기가 해먹 줄의 매듭 바로 아래에 오게 잡았다(좌우 대칭).
    static func palmOrigin(_ side: PalmSide) -> CGPoint {
        switch side {
        case .left: return CGPoint(x: -118, y: 150)
        case .right: return CGPoint(x: canvas + 118 - 1024 * palmScale, y: 150)
        }
    }

    static func palmTrunk(_ side: PalmSide) -> Piece {
        side == .left ? Piece("vacation_palm_left_trunk", 226, 298, 548, 1302) : Piece("vacation_palm_right_trunk", 250, 298, 548, 1302)
    }

    /// 잎은 줄기 꼭대기를 중심으로 흔들린다.
    static func palmFronds(_ side: PalmSide) -> Piece {
        side == .left
            ? Piece("vacation_palm_left_fronds", 86, 118, 938, 540, pivot: CGPoint(x: 530, y: 390))
            : Piece("vacation_palm_right_fronds", 0, 118, 938, 540, pivot: CGPoint(x: 494, y: 390))
    }

    static func palmCoconuts(_ side: PalmSide) -> Piece {
        side == .left ? Piece("vacation_palm_left_coconuts", 428, 352, 176, 146) : Piece("vacation_palm_right_coconuts", 420, 352, 176, 146)
    }

    /// 나무 조각의 자리를 포즈 단위로 옮긴다.
    static func palmRect(_ piece: Piece, side: PalmSide) -> CGRect {
        let origin = palmOrigin(side)
        return CGRect(
            x: origin.x + piece.rect.minX * palmScale, y: origin.y + piece.rect.minY * palmScale,
            width: piece.rect.width * palmScale, height: piece.rect.height * palmScale
        )
    }

    /// 두 나무까지 포함한 장면의 너비(포즈 단위의 배수).
    static let rigWidthRatio: CGFloat = (canvas + 118 * 2) / canvas

    // MARK: - 배경(2400 단위)

    static let sceneCanvas: CGFloat = 2400
    /// 산·바다·모래·꽃. 위쪽(하늘)은 투명하다.
    static let scenery = CGRect(x: 0, y: 1192, width: 2400, height: 1208)
    /// 풍경 그림에서 모래가 시작되는 높이(가운데 기준)와, 하늘 띠가 끝나는 높이.
    static let scenerySandLine: CGFloat = 1935
    static let skyBottom: CGFloat = 1400
    /// 해(달)와 그 빛. 원반의 가운데는 그림의 가운데다.
    static let sun = CGSize(width: 704, height: 692)
    /// 구름 한 덩이. 넷이 같은 모양이고 크기만 다르다.
    static let cloud = CGSize(width: 352, height: 218)
    /// 별: 하늘 위쪽에 흩어져 있다.
    static let stars = CGRect(x: 164, y: 114, width: 2090, height: 910)

    /// 구름의 자리(가로는 화면 너비의, 세로는 하늘 높이의 비율)와 크기 배율, 흐르는 거리(pt)와 한쪽으로 가는 시간(초).
    struct Cloud: Equatable, Sendable {
        let x: CGFloat, y: CGFloat, scale: CGFloat, drift: CGFloat, duration: Double
    }

    static let clouds = [
        Cloud(x: 0.19, y: 0.51, scale: 1, drift: 14, duration: 12),
        Cloud(x: 0.64, y: 0.35, scale: 0.82, drift: 11, duration: 15),
        Cloud(x: 0.9, y: 0.6, scale: 1.2, drift: 16, duration: 13),
        Cloud(x: 0.36, y: 0.29, scale: 0.68, drift: 9, duration: 10),
    ]

    /// 풍경 아래로 이어 칠하는 모래의 색(풍경 그림의 맨 아랫줄 색).
    static func sandColor(isDark: Bool) -> CGColor {
        isDark
            ? CGColor(srgbRed: 0xD2 / 255, green: 0xAC / 255, blue: 0x9A / 255, alpha: 1)
            : CGColor(srgbRed: 0xEF / 255, green: 0xC7 / 255, blue: 0x8D / 255, alpha: 1)
    }

    static func name(_ base: String, isDark: Bool) -> String { "\(base)_\(isDark ? "night" : "day")" }

    // MARK: - 크기

    /// 해먹(포즈 정사각형)의 한 변(pt). 화면 너비에 맞추되, 문구와 단추가 한 화면에 들어가도록 높이도 본다.
    /// `reserved`는 해먹 말고 나머지(문구, 진행 카드, 단추, 여백)가 쓰는 높이다.
    static func hammockSide(pane: CGSize, reserved: CGFloat) -> CGFloat {
        // 좁은 화면에서는 나무의 잎 끝이 화면 밖으로 조금 나가도 해먹을 크게 보여 준다.
        let byWidth = pane.width * 0.95
        let byHeight = (pane.height - reserved) / (slotHeight / canvas)
        return min(max(min(byWidth, byHeight, 720), 210), max(byWidth, 120))
    }
}

/// 휴가 장면의 자리 계산. 화면의 크기와 해먹이 놓일 띠(`slot`)에서 모든 조각의 자리를 정한다(pt, 위에서 아래로).
///
/// 배경은 해먹에 맞춘다: 모래가 시작되는 선이 야자나무의 밑동을 지나게 놓고, 그 위로 하늘을, 아래로 모래를 이어 채운다.
/// 풍경(산·바다)은 해먹보다 지나치게 커지지 않게 하고, 화면이 그보다 넓으면 좌우로 뒤집어 이어 붙인다.
struct VacationSceneLayout: Equatable, Sendable {
    var pane: CGSize
    /// 해먹이 놓일 띠: 너비가 포즈 정사각형의 한 변이고, 높이는 그 `slotHeight / canvas`배다.
    var slot: CGRect
    /// 위쪽 안전 영역(상태 표시줄, 도구 막대). 해와 구름을 그 아래에 둔다.
    var topInset: CGFloat = 0

    /// 포즈 단위 1이 몇 pt인지.
    var unit: CGFloat { slot.width / VacationArt.canvas }
    /// 포즈 정사각형의 왼쪽 위.
    var poseOrigin: CGPoint { CGPoint(x: slot.minX, y: slot.minY - VacationArt.slotTop * unit) }
    var sandY: CGFloat { poseOrigin.y + VacationArt.sandLine * unit }

    /// 풍경 그림 한 장의 너비: 화면 너비에 맞추되 해먹의 1.17배(받은 구도)보다 작지 않고 1.55배보다 크지 않다.
    var sceneryWidth: CGFloat { min(max(pane.width, slot.width * 1.17), slot.width * 1.55) }
    /// 배경 단위 1이 몇 pt인지.
    var sceneScale: CGFloat { sceneryWidth / VacationArt.sceneCanvas }

    /// 포즈 단위의 자리를 화면의 포즈 정사각형 안 자리(pt)로.
    func rect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX * unit, y: rect.minY * unit, width: rect.width * unit, height: rect.height * unit)
    }

    /// 가운데 풍경의 자리. 모래선이 `sandY`에 온다.
    var sceneryFrame: CGRect {
        let scale = sceneScale
        return CGRect(
            x: (pane.width - sceneryWidth) / 2, y: sandY - (VacationArt.scenerySandLine - VacationArt.scenery.minY) * scale,
            width: sceneryWidth, height: VacationArt.scenery.height * scale
        )
    }

    /// 가운데 풍경의 양옆에 더 붙여야 하는 장 수(한쪽). 홀수 번째는 좌우를 뒤집어 이음매를 맞춘다.
    var sceneryTilesPerSide: Int {
        let gap = (pane.width - sceneryWidth) / 2
        return gap > 0.5 ? Int((gap / sceneryWidth).rounded(.up)) : 0
    }

    /// 하늘: 화면 맨 위에서 산 뒤까지.
    var skyFrame: CGRect {
        let bottom = sandY - (VacationArt.scenerySandLine - VacationArt.skyBottom) * sceneScale
        return CGRect(x: 0, y: 0, width: pane.width, height: max(bottom, 0))
    }

    /// 풍경 아래로 화면 끝까지 이어지는 모래.
    var sandFrame: CGRect {
        let top = sceneryFrame.maxY - 1
        return CGRect(x: 0, y: top, width: pane.width, height: max(pane.height - top, 0))
    }

    /// 산꼭대기의 높이. 해와 구름은 화면 위(안전 영역 아래)에서 여기까지의 하늘에 둔다.
    var peaksY: CGFloat { sceneryFrame.minY }
    private var skyHeight: CGFloat { max(peaksY - topInset, 0) }

    var sunFrame: CGRect {
        let scale = sceneScale
        let size = CGSize(width: VacationArt.sun.width * scale, height: VacationArt.sun.height * scale)
        // 원반(그림 너비의 0.36)이 위에서 잘리지 않게 한다.
        let centerY = max(topInset + skyHeight * 0.3, topInset + size.height * 0.22)
        return CGRect(x: pane.width * 0.84 - size.width / 2, y: centerY - size.height / 2, width: size.width, height: size.height)
    }

    func cloudFrame(_ cloud: VacationArt.Cloud) -> CGRect {
        let scale = sceneScale * cloud.scale
        let size = CGSize(width: VacationArt.cloud.width * scale, height: VacationArt.cloud.height * scale)
        return CGRect(
            x: pane.width * cloud.x - size.width / 2, y: topInset + skyHeight * cloud.y - size.height / 2,
            width: size.width, height: size.height
        )
    }

    /// 별: 화면 너비를 다 덮게 놓는다.
    var starsFrame: CGRect {
        let width = max(pane.width, sceneryWidth)
        let scale = width / VacationArt.sceneCanvas
        return CGRect(
            x: (pane.width - width) / 2 + VacationArt.stars.minX * scale, y: VacationArt.stars.minY * scale,
            width: VacationArt.stars.width * scale, height: VacationArt.stars.height * scale
        )
    }
}

/// 휴가 화면의 그림을 표시 크기에 딱 맞게 줄여 둔다(새싹이와 같은 이유: 큰 그림을 그리는 자리에서 줄이면 선이 뭉개진다).
@MainActor
enum VacationArtRenderer {
    private struct Key: Hashable {
        let asset: String
        let width: Int
        let height: Int
    }

    /// 기억해 두는 그림 수의 상한. 창 크기를 바꾸면 크기별로 쌓이므로, 넘으면 비우고 다시 만든다.
    static let cacheLimit = 56
    private static var cache: [Key: CGImage] = [:]

    /// `asset`을 `pixels` 크기로 줄인 그림. 원본보다 크게는 만들지 않는다(그때는 원본을 그대로 쓴다).
    static func image(_ asset: String, pixels: CGSize) -> CGImage? {
        let width = Int(pixels.width.rounded()), height = Int(pixels.height.rounded())
        guard width > 0, height > 0 else { return nil }
        let key = Key(asset: asset, width: width, height: height)
        if let cached = cache[key] { return cached }
        guard let source = source(asset) else { return nil }
        let image = width >= source.width || height >= source.height ? source : (downsample(source, width: width, height: height) ?? source)
        if cache.count >= cacheLimit { cache.removeAll() }
        cache[key] = image
        return image
    }

    static func source(_ asset: String) -> CGImage? {
        #if os(macOS)
        return NSImage(named: asset)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return UIImage(named: asset)?.cgImage
        #endif
    }

    private static func downsample(_ source: CGImage, width: Int, height: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let full = CGContext(
            data: nil, width: source.width, height: source.height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info
        ), let output = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info
        ) else { return nil }
        full.interpolationQuality = .none
        full.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        guard let fullData = full.data, let outputData = output.data else { return nil }
        var input = vImage_Buffer(
            data: fullData, height: vImagePixelCount(source.height), width: vImagePixelCount(source.width), rowBytes: full.bytesPerRow
        )
        var result = vImage_Buffer(
            data: outputData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: output.bytesPerRow
        )
        guard vImageScale_ARGB8888(&input, &result, nil, vImage_Flags(kvImageHighQualityResampling)) == kvImageNoError else {
            return nil
        }
        return output.makeImage()
    }
}
