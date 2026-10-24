import Testing
import QuartzCore
@testable import Daylog

@MainActor
struct PioOutfitMotionTests {
    @Test func capabilitiesNeverPretendCostumesHaveIndependentPartsOrGrowthArt() {
        for outfit in PioOutfitID.allCases {
            let support = PioOutfitCapabilities(outfit: outfit)
            #expect(!support.hasIndependentBlink && !support.hasIndependentWalk)
            #expect(!support.hasIndependentRun && !support.hasIndependentFlap)
            #expect(!support.hasStageSpecificArtwork)
            #expect(support.hasIndependentWingWave == (outfit == .basic))
            #expect(support.supportedMotions.contains(.wave) == (outfit == .basic))
            for stage in 1...4 { #expect(support.stageSupport(stage) == .partial) }
            #expect(support.stageSupport(0) == .unsupported)
            #expect(support.stageSupport(5) == .unsupported)
        }
    }

    #if DEBUG
    @Test func visibilityPauseAndReduceMotionRemoveAllTracksIncludingTheBasicWing() {
        let rig = PioOutfitMotionRig()
        let scenarios: [(PioOutfitID, PioOutfitMotion)] = [(.halloween, .jump), (.basic, .wave)]
        for (outfit, motion) in scenarios {
            rig.configure(outfit: outfit, stage: 1, motion: motion)
            rig.setAnimating(true)
            #expect(rig.animationCount > 0)
            let count = rig.animationCount
            rig.setAnimating(true)
            #expect(rig.animationCount == count)
            // The view feeds false for offscreen, inactive scene and dismantling.
            rig.setAnimating(false)
            #expect(rig.animationCount == 0)
            #expect(CATransform3DIsIdentity(rig.artwork.transform))
            rig.setAnimating(true, reduceMotion: true)
            #expect(rig.animationCount == 0)
            rig.setAnimating(true)
            #expect(rig.animationCount > 0)
            rig.setAnimating(true, reduceMotion: true)
            #expect(rig.animationCount == 0)
        }
    }

    @Test func unchangedUpdatesAndPartialStageChangesDoNotReconfigureOrDecode() {
        let rig = PioOutfitMotionRig()
        rig.configure(outfit: .hanbok, stage: 1, motion: .idle)
        rig.setAnimating(true)
        let configurations = rig.configurationCount
        let decodes = PioOutfitMotionImageCache.decodeCount
        let image = rig.artwork.contents as AnyObject?
        for stage in [1, 2, 3, 4, 4] {
            rig.configure(outfit: .hanbok, stage: stage, motion: .idle)
            rig.layout(in: CGRect(x: 0, y: 0, width: 220, height: 220), displayScale: 3)
            #expect(rig.configurationCount == configurations)
            #expect(PioOutfitMotionImageCache.decodeCount == decodes)
            #expect((rig.artwork.contents as AnyObject?) === image)
            #expect(rig.animationCount == 1)
            #expect(rig.stage == stage)
        }
        rig.configure(outfit: .hanbok, stage: 4, motion: .celebration)
        #expect(rig.configurationCount == configurations + 1)
        #expect(PioOutfitMotionImageCache.decodeCount == decodes)
        rig.setAnimating(false)
    }

    @Test func decodedArtworkIsReusedAndUnsupportedWaveFallsBackHonestly() throws {
        let image = try #require(PioOutfitMotionImageCache.image(for: .astronaut))
        let decoded = PioOutfitMotionImageCache.decodeCount
        let second = try #require(PioOutfitMotionImageCache.image(for: .astronaut))
        #expect(image === second)
        #expect(PioOutfitMotionImageCache.decodeCount == decoded)
        let rig = PioOutfitMotionRig()
        rig.configure(outfit: .astronaut, stage: 4, motion: .wave)
        #expect(rig.motion == .idle)
        #expect(rig.outfit == .astronaut)
        rig.setAnimating(true)
        #expect(rig.animationCount == 1)
        #expect(rig.artwork.animation(forKey: "outfit.breath") != nil)
        rig.configure(outfit: .christmas, stage: 4, motion: .landing)
        #expect(rig.motion == .landing && rig.outfit == .christmas)
        #expect(rig.animationCount == 2)
        rig.setAnimating(false)
        #expect(rig.animationCount == 0)
    }
    #endif
}
