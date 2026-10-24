import Accelerate
import CoreGraphics
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 새싹이 그림을 표시 크기와 화면 배율에 딱 맞게 줄여 둔다.
///
/// 원본(1024픽셀)은 그대로 두고, 필요한 크기마다 한 번만 고품질(Lanczos)로 줄여 기억한다. 같은 크기를 다시 그릴 때는
/// 만들어 둔 그림을 그대로 쓴다. 크기는 화면에서 쓰는 몇 가지뿐이라(36~60pt, 안내 화면 132pt) 만드는 횟수도 그만큼이다.
@MainActor
enum SaessagiRenderer {
    /// 틀 바깥으로 남겨 두는 여백(pt). 외곽선의 가장자리가 틀에서 잘리지 않게 한다. 정수라 어느 배율에서도 픽셀에 맞는다.
    nonisolated static let padding: CGFloat = 2
    /// 기억해 두는 그림 수의 상한. 넘으면 비우고 다시 만든다(평소에는 닿지 않는다).
    static let cacheLimit = 64

    private struct Key: Hashable {
        /// 그림의 에셋 이름. 대기 애니메이션의 레이어는 기본 모습과 자리가 같고 이름만 다르다.
        let asset: String
        let pose: SaessagiPose
        /// 만든 그림의 한 변(픽셀).
        let side: Int
        /// 캐릭터가 차지하는 길이(픽셀). 같은 한 변이라도 배율이 다르면 여백이 달라진다.
        let fitted: Int
    }

    private static var cache: [Key: CGImage] = [:]

    /// `size`pt 틀에 그릴 그림. 한 변은 `(size + 2 × padding) × displayScale` 픽셀이고, 캐릭터는 가로 가운데·바닥에서 `padding` 위에 있다.
    static func image(pose: SaessagiPose, size: CGFloat, displayScale: CGFloat) -> CGImage? {
        image(asset: pose.assetName, pose: pose, size: size, displayScale: displayScale)
    }

    /// `pose`와 같은 자리·같은 배율로 `asset`을 그린 그림. 레이어들이 서로, 그리고 한 장짜리 그림과 정확히 겹친다.
    static func image(asset: String, pose: SaessagiPose, size: CGFloat, displayScale: CGFloat, padding: CGFloat = SaessagiRenderer.padding) -> CGImage? {
        let scale = max(displayScale, 1)
        let side = Int(((size + padding * 2) * scale).rounded())
        let fitted = Int((size * scale).rounded())
        guard side > 0, fitted > 0 else { return nil }
        let key = Key(asset: asset, pose: pose, side: side, fitted: fitted)
        if let cached = cache[key] { return cached }
        guard let source = sourceImage(asset), let image = downsample(source, pose: pose, side: side, fitted: fitted) else {
            return nil
        }
        if cache.count >= cacheLimit { cache.removeAll() }
        cache[key] = image
        return image
    }

    private static func sourceImage(_ asset: String) -> CGImage? {
        #if os(macOS)
        return NSImage(named: asset)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        return UIImage(named: asset)?.cgImage
        #endif
    }

    /// 원본 그림 위의 한 점(1024 기준 픽셀, 위에서 아래로)이 만들어 둔 그림 안에서 어디인지(0…1).
    /// 레이어를 돌리거나 접을 때의 기준점으로 쓴다.
    static func unitPoint(of source: CGPoint, pose: SaessagiPose, size: CGFloat, padding: CGFloat = SaessagiRenderer.padding) -> CGPoint {
        let scale = size / pose.fitted
        let x = size / 2 + (source.x - pose.content.midX) * scale
        let y = size - (pose.content.maxY - source.y) * scale
        let side = size + padding * 2
        return CGPoint(x: (x + padding) / side, y: (y + padding) / side)
    }

    /// 캐릭터 자리를 원본 해상도로 잘라 낸 뒤 한 번에 줄인다.
    private static func downsample(_ source: CGImage, pose: SaessagiPose, side: Int, fitted: Int) -> CGImage? {
        // 원본이 1024가 아니어도 같은 비율로 본다.
        let unit = CGFloat(source.width) / SaessagiPose.canvas
        let content = pose.content.applying(CGAffineTransform(scaleX: unit, y: unit))
        // 만들 그림의 한 변이 원본에서 차지하는 길이: 캐릭터의 긴 변에 여백을 더한 만큼.
        let cropSide = Int((pose.fitted * unit * CGFloat(side) / CGFloat(fitted)).rounded())
        let margin = (CGFloat(cropSide) - pose.fitted * unit) / 2
        guard cropSide > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let crop = CGContext(
            data: nil, width: cropSide, height: cropSide, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info
        ), let output = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info
        ) else { return nil }

        // 캐릭터의 가로 가운데를 가운데로, 발밑을 바닥에서 여백만큼 위로. CoreGraphics는 아래가 원점이다.
        // 원본 픽셀에 맞춰 옮기기만 하므로 여기서는 보간이 없다.
        crop.interpolationQuality = .none
        let x = (CGFloat(cropSide) / 2 - content.midX).rounded()
        let y = (margin - (CGFloat(source.height) - content.maxY)).rounded()
        crop.draw(source, in: CGRect(x: x, y: y, width: CGFloat(source.width), height: CGFloat(source.height)))

        guard let cropData = crop.data, let outputData = output.data else { return nil }
        var input = vImage_Buffer(
            data: cropData, height: vImagePixelCount(cropSide), width: vImagePixelCount(cropSide), rowBytes: crop.bytesPerRow
        )
        var result = vImage_Buffer(
            data: outputData, height: vImagePixelCount(side), width: vImagePixelCount(side), rowBytes: output.bytesPerRow
        )
        // 고품질 리샘플링(Lanczos). 크게 줄여도 가는 선이 빠지지 않는다.
        guard vImageScale_ARGB8888(&input, &result, nil, vImage_Flags(kvImageHighQualityResampling)) == kvImageNoError else {
            return nil
        }
        return output.makeImage()
    }
}
