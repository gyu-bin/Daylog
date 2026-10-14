import Foundation
import Testing
@testable import Daylog
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 새싹이: 그림이 다 들어 있는지, 어느 모습을 언제 보여 주는지.
@MainActor
struct SaessagiTests {
    private let day = Day(year: 2026, month: 10, day: 14)

    @Test func everyPoseHasItsImage() {
        for pose in SaessagiPose.allCases {
            #if os(macOS)
            let image = NSImage(named: pose.assetName)
            #else
            let image = UIImage(named: pose.assetName)
            #endif
            #expect(image != nil, "\(pose.assetName) 그림이 없다")
        }
    }

    @Test func everyPoseFitsTheSharedScale() {
        for pose in SaessagiPose.allCases {
            let content = pose.content
            // 캐릭터가 캔버스 안에 있고, 긴 변이 틀에 꼭 맞는다(틀을 넘지 않는다).
            #expect(content.minX >= 0 && content.minY >= 0)
            #expect(content.maxX <= SaessagiPose.canvas && content.maxY <= SaessagiPose.canvas)
            #expect(content.width <= pose.fitted && content.height <= pose.fitted)
            #expect(pose.fitted == max(content.width, content.height))
        }
    }

    @Test func rendererMakesOnePixelExactImagePerSizeAndScale() throws {
        for pose in SaessagiPose.allCases {
            for (size, scale) in [(36.0, 1.0), (48.0, 1.0), (48.0, 2.0), (60.0, 3.0), (132.0, 2.0)] {
                let image = try #require(SaessagiRenderer.image(pose: pose, size: size, displayScale: scale))
                // 틀에 여백을 더한 크기 그대로(화면에서 다시 줄이지 않는다).
                let side = Int((size + SaessagiRenderer.padding * 2) * scale)
                #expect(image.width == side && image.height == side)
                // 같은 크기를 다시 달라고 하면 만들어 둔 그림을 그대로 준다.
                #expect(SaessagiRenderer.image(pose: pose, size: size, displayScale: scale) === image)
            }
        }
    }

    @Test func renderedCharacterFillsTheFrameAndStaysInsideThePadding() throws {
        for pose in SaessagiPose.allCases {
            let size = 48.0, scale = 2.0
            let image = try #require(SaessagiRenderer.image(pose: pose, size: size, displayScale: scale))
            let side = image.width
            var pixels = [UInt8](repeating: 0, count: side * side * 4)
            let context = try #require(CGContext(
                data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            // 불투명에 가까운 픽셀이 차지하는 범위(위에서 아래로).
            var minX = side, maxX = -1, minY = side, maxY = -1
            for y in 0..<side {
                for x in 0..<side where pixels[(y * side + x) * 4 + 3] > 128 {
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            let padding = Int(SaessagiRenderer.padding * scale)
            let frame = Int(size * scale)
            // 캐릭터의 긴 변이 틀(여백 안쪽)에 거의 꼭 맞고, 발밑이 틀의 바닥에 온다. 줄이면서 한두 픽셀은 달라질 수 있다.
            #expect(max(maxX - minX, maxY - minY) + 1 >= frame - 3 && max(maxX - minX, maxY - minY) + 1 <= frame + 2)
            #expect(abs(maxY - (side - padding - 1)) <= 2)
            // 가로는 가운데.
            #expect(abs((minX + maxX) / 2 - side / 2) <= 2)
            // 여백 덕분에 그림의 가장자리에서 잘리지 않는다.
            #expect(minX >= 1 && minY >= 1 && maxX <= side - 2 && maxY <= side - 2)
        }
    }

    @Test func restsOnVacationAndSmilesOtherwise() {
        #expect(SaessagiMood.base(isVacation: false) == .idle)
        #expect(SaessagiMood.base(isVacation: true) == .rest)
    }

    @Test func reactsToCompletingAndSkipping() {
        let before = SaessagiProgress(day: day, done: 1, skipped: 0)
        // 완료가 늘면 기뻐한다.
        #expect(SaessagiMood.reaction(from: before, to: SaessagiProgress(day: day, done: 2, skipped: 0)) == .completed)
        // 건너뜀이 늘면 쉰다.
        #expect(SaessagiMood.reaction(from: before, to: SaessagiProgress(day: day, done: 1, skipped: 1)) == .skipped)
        // 완료를 건너뜀으로 바꾸면 쉰다, 건너뜀을 완료로 바꾸면 기뻐한다.
        #expect(SaessagiMood.reaction(from: before, to: SaessagiProgress(day: day, done: 0, skipped: 1)) == .skipped)
        #expect(SaessagiMood.reaction(
            from: SaessagiProgress(day: day, done: 0, skipped: 1), to: SaessagiProgress(day: day, done: 1, skipped: 0)
        ) == .completed)
        #expect(SaessagiReaction.completed.pose == .happy)
        #expect(SaessagiReaction.skipped.pose == .rest)
    }

    @Test func staysCalmWhenNothingWasAdded() {
        let before = SaessagiProgress(day: day, done: 2, skipped: 1)
        // 취소(완료 해제, 건너뜀 해제)에는 반응하지 않는다.
        #expect(SaessagiMood.reaction(from: before, to: SaessagiProgress(day: day, done: 1, skipped: 1)) == nil)
        #expect(SaessagiMood.reaction(from: before, to: SaessagiProgress(day: day, done: 2, skipped: 0)) == nil)
        #expect(SaessagiMood.reaction(from: before, to: before) == nil)
        // 날짜를 옮겨서 개수가 달라진 것은 반응할 일이 아니다.
        let otherDay = Day(year: 2026, month: 10, day: 13)
        #expect(SaessagiMood.reaction(from: before, to: SaessagiProgress(day: otherDay, done: 5, skipped: 3)) == nil)
    }
}
