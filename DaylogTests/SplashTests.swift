import Foundation
import Testing
@testable import Daylog

/// 스플래시의 시간표와 "언제 트는가" 규칙. 화면 자체는 시뮬레이터 녹화로 확인한다(docs/splash).
@MainActor
struct SplashTests {
    @Test func standardTimelineHoldsTheFinishedSplashForAboutOneAndAHalfSeconds() {
        let timeline = SplashTimeline.standard
        #expect(timeline.steps.map(\.stage) == [.grown, .logo, .settled, .leaving])
        // 장면은 시간 순서대로 시작한다.
        #expect(timeline.steps.map(\.at) == timeline.steps.map(\.at).sorted())
        // 들어왔다가 걷히기까지 2초대. 완성된 장면(이름·문구)은 1~2초 머문다.
        #expect(timeline.total >= 2.0 && timeline.total <= 2.6)
        let leaving = timeline.steps.first { $0.stage == .leaving }?.at ?? 0
        let readable = leaving - timeline.logoVisibleAt
        #expect(timeline.logoVisibleAt < leaving)
        #expect(readable >= 1.0 && readable <= 2.0)
        #expect(!timeline.reducesMotion)
    }

    @Test func reducedMotionSkipsGrowthAndMovementAndIsShorter() {
        let timeline = SplashTimeline.reduced
        // 커지고 올라가고 흔들리는 장면이 없다: 글자가 나타났다가 걷힐 뿐이다.
        #expect(timeline.steps.map(\.stage) == [.logo, .leaving])
        #expect(timeline.reducesMotion)
        #expect(timeline.total < SplashTimeline.standard.total)
        let leaving = timeline.steps.first { $0.stage == .leaving }?.at ?? 0
        #expect(leaving - timeline.logoVisibleAt >= 1.0)
        #expect(SplashTimeline.make(reduceMotion: true) == .reduced)
        #expect(SplashTimeline.make(reduceMotion: false) == .standard)
    }

    @Test func unstartedSplashDoesNotLingerLongerThanTheGracePeriod() {
        // 화면 없이 실행된 경우에 스플래시가 오래 남지 않는다.
        #expect(SplashTimeline.startGrace > 0 && SplashTimeline.startGrace <= 2)
    }

    @Test func splashPlaysOncePerProcess() {
        SplashPolicy.resetForTesting()
        defer { SplashPolicy.resetForTesting() }
        // 처음 뜨는 화면만 튼다.
        #expect(SplashPolicy.claim(isRunningTests: false))
        // 백그라운드에서 돌아와 화면이 다시 만들어지거나, 두 번째 창이 열려도 다시 틀지 않는다.
        #expect(!SplashPolicy.claim(isRunningTests: false))
        #expect(!SplashPolicy.claim(isRunningTests: false))
    }

    @Test func splashNeverPlaysUnderTests() {
        SplashPolicy.resetForTesting()
        defer { SplashPolicy.resetForTesting() }
        #expect(!SplashPolicy.claim(isRunningTests: true))
        // 테스트 호스트에서 물어본 것은 차례를 쓰지 않는다.
        #expect(SplashPolicy.claim(isRunningTests: false))
    }

    @Test func stagesAreOrdered() {
        #expect(SplashTimeline.Stage.start < .grown)
        #expect(SplashTimeline.Stage.grown < .logo)
        #expect(SplashTimeline.Stage.logo < .settled)
        #expect(SplashTimeline.Stage.settled < .leaving)
    }
}
