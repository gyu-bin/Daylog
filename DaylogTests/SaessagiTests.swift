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
            // 캐릭터가 캔버스 안에 있고, 같은 배율로 그렸을 때 틀을 넘지 않는다.
            #expect(content.minX >= 0 && content.minY >= 0)
            #expect(content.maxX <= SaessagiPose.canvas && content.maxY <= SaessagiPose.canvas)
            #expect(content.width <= SaessagiPose.fitted && content.height <= SaessagiPose.fitted)
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
