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
        #expect(SplashTimeline.make(reduceMotion: true).steps.map(\.stage) == SplashTimeline.reduced.steps.map(\.stage))
        #expect(SplashTimeline.make(reduceMotion: false).steps.map(\.stage) == SplashTimeline.standard.steps.map(\.stage))
    }

    @Test func durationComesFromTheSettingAndKeepsTheSceneProportions() {
        // 기본값은 1.5초.
        let standard = SplashTimeline.make(reduceMotion: false)
        #expect(abs(standard.total - 1.5) < 0.0001)
        #expect(MobileUISettings.builtInSplashDuration == 1.5)
        // 설정한 시간만큼 재생한다(0.5~2초).
        for seconds in [0.5, 0.8, 1.5, 2.0] {
            let timeline = SplashTimeline.make(reduceMotion: false, duration: seconds)
            #expect(abs(timeline.total - seconds) < 0.0001)
            // 장면의 순서와 비율은 그대로다.
            #expect(timeline.steps.map(\.stage) == SplashTimeline.standard.steps.map(\.stage))
            let ratio = timeline.total / SplashTimeline.standard.total
            for (scaled, base) in zip(timeline.steps, SplashTimeline.standard.steps) {
                #expect(abs(scaled.at - base.at * ratio) < 0.0001)
            }
            // 이름과 문구가 다 나타난 뒤에 걷히기 시작한다.
            #expect(timeline.logoVisibleAt < (timeline.steps.last?.at ?? 0))
        }
        // 범위를 벗어난 값은 기본값으로 재생한다.
        for bad in [0, 0.49, 2.01, 30, -1, Double.nan, Double.infinity] {
            #expect(abs(SplashTimeline.make(reduceMotion: false, duration: bad).total - 1.5) < 0.0001)
        }
        // 동작 줄이기에서는 같은 비율로 더 짧다.
        let reduced = SplashTimeline.make(reduceMotion: true, duration: 2.0)
        #expect(reduced.total < 2.0 && reduced.reducesMotion)
        #expect(abs(reduced.total - SplashTimeline.reduced.total * 2.0 / SplashTimeline.standard.total) < 0.0001)
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

    @Test func pioPerformanceFinishesBeforeTheDefaultSplashLeaves() {
        let timeline = SplashTimeline.make(reduceMotion: false)
        let appears = timeline.steps.first { $0.stage == .grown }!.at
        let leaving = timeline.steps.first { $0.stage == .leaving }!.at
        #expect(appears + SplashView.Performance.duration <= leaving)
    }

    @Test func pioFigureDrawsEveryLayerInOrderAndTurnsAroundItsOwnJoints() {
        let parts = SplashView.Figure.parts
        #expect(parts.map(\.asset) == ["wingLeft", "wingRight", "footLeft", "footRight", "sprout", "body",
                                       "eyeLeft", "eyeRight", "lidLeft", "lidRight"])
        for part in parts {
            #expect(part.rect.insetBy(dx: -1, dy: -1).contains(part.pivot), "\(part.asset) turns around a point on itself")
        }
        // 날개·새싹이 도는 범위는 밑동이 몸에 가려지는 것을 확인한 범위 안이다(연기에 쓰는 가장 큰 값).
        #expect(SplashView.Performance.rightWingRange.contains(-14) && SplashView.Performance.rightWingRange.contains(8))
        #expect(SplashView.Performance.leftWingRange.contains(16) && SplashView.Performance.leftWingRange.contains(-6))
        #expect(SplashView.Performance.sproutRange.contains(-10) && SplashView.Performance.sproutRange.contains(10))
    }
}
