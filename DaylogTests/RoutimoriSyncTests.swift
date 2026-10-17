import QuartzCore
import Testing
@testable import Daylog

@MainActor
struct RoutimoriSyncTests {
    @Test func sceneTransitionReplacesMotionAndReduceMotionStopsEveryLayer() {
        let stage = RoutimoriSyncStage()
        var config = RoutimoriSyncStage.Configuration(kind: .receiving, height: 340, dark: false, scale: 2, reduceMotion: false)
        stage.update(config, isAnimating: true)
        #expect(stage.character.animation(forKey: "attention") != nil)
        #expect(stage.glyph.animation(forKey: "receiving") != nil)
        config.kind = .ready
        stage.update(config, isAnimating: true)
        #expect(stage.character.animation(forKey: "attention") == nil)
        #expect(stage.character.animation(forKey: "celebration")?.repeatCount == 0)
        #expect(stage.glyph.animation(forKey: "receiving") == nil)
        config.kind = .trouble
        stage.update(config, isAnimating: true)
        #expect(stage.character.animation(forKey: "celebration") == nil)
        #expect(stage.character.animation(forKey: "concern")?.repeatCount == 0)
        config.reduceMotion = true
        // Even a caller passing true cannot bypass Reduce Motion.
        stage.update(config, isAnimating: true)
        for layer in [stage.character, stage.cloud, stage.glyph] {
            #expect(layer.animationKeys()?.isEmpty ?? true)
            #expect(CATransform3DIsIdentity(layer.transform))
        }
        config.reduceMotion = false
        stage.update(config, isAnimating: true)
        #expect(stage.character.animation(forKey: "breathing") != nil)
        stage.halt()
        #expect(stage.character.animationKeys()?.isEmpty ?? true)
        stage.update(config, isAnimating: true)
        #expect(stage.character.animation(forKey: "breathing") != nil)
    }

    @Test func repeatedUpdatesDoNotAccumulateTracksAndActivityStops() {
        let stage = RoutimoriSyncStage()
        let config = RoutimoriSyncStage.Configuration(kind: .receiving, height: 220, dark: true, scale: 3, reduceMotion: false)
        stage.update(config, isAnimating: true)
        stage.update(config, isAnimating: true)
        #expect(Set(stage.character.animationKeys() ?? []) == ["breathing", "attention"])
        #expect(stage.root.sublayers?.count == 3)
        let activity = RoutimoriSyncActivityStage()
        let restPosition = activity.segment.position
        activity.update(isAnimating: true)
        #expect(activity.segment.animation(forKey: "activity")?.repeatCount == .infinity)
        activity.update(isAnimating: false)
        #expect(activity.segment.animationKeys()?.isEmpty ?? true)
        #expect(activity.segment.position == restPosition)
        #expect(CATransform3DIsIdentity(activity.segment.transform))
    }
}
