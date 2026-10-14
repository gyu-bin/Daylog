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

    // MARK: - 대기 애니메이션

    @Test func idleLayersLineUpWithTheSinglePicture() throws {
        #expect(SaessagiIdleLayers.all.count == 6)
        for asset in SaessagiIdleLayers.all {
            #expect(NSImage(named: asset) != nil, "\(asset) 그림이 없다")
            // 레이어는 기본 그림과 같은 크기로 만들어져 정확히 겹친다.
            let whole = try #require(SaessagiRenderer.image(pose: .idle, size: 48, displayScale: 2))
            let layer = try #require(SaessagiRenderer.image(asset: asset, pose: .idle, size: 48, displayScale: 2))
            #expect(layer.width == whole.width && layer.height == whole.height)
        }
    }

    @Test func idleAnchorsSitInsideTheCharacter() {
        for size in [36.0, 48.0, 132.0] {
            let pivot = SaessagiRenderer.unitPoint(of: SaessagiIdleLayers.leafPivot, pose: .idle, size: size)
            let eyes = SaessagiRenderer.unitPoint(of: SaessagiIdleLayers.eyeCenter, pose: .idle, size: size)
            // 줄기 밑동은 가로 가운데, 위에서 4분의 1쯤. 눈은 그보다 아래, 발보다 위.
            #expect(abs(pivot.x - 0.5) < 0.02 && pivot.y > 0.15 && pivot.y < 0.4)
            #expect(abs(eyes.x - 0.5) < 0.02 && eyes.y > pivot.y && eyes.y < 0.75)
        }
        // 그림의 발밑 가운데는 틀의 바닥 가운데(여백 안쪽)다.
        let content = SaessagiPose.idle.content
        let foot = SaessagiRenderer.unitPoint(of: CGPoint(x: content.midX, y: content.maxY), pose: .idle, size: 48)
        #expect(abs(foot.x - 0.5) < 0.001)
        #expect(abs(foot.y - (48 + SaessagiRenderer.padding) / (48 + SaessagiRenderer.padding * 2)) < 0.001)
    }

    @Test func idleMotionStaysSmallAndBlinksEveryFewSeconds() {
        let starts = SaessagiIdleMotion.blinkStarts
        // 깜빡임 사이는 3~5초다(한 바퀴를 돌아 다시 시작할 때도). 붙어 있는 한 쌍은 두 번 연달아 깜빡이는 것이다.
        var gaps = zip(starts.dropFirst(), starts).map { $0 - $1 }
        gaps.append(starts[0] + SaessagiIdleMotion.blinkCycle - starts[starts.count - 1])
        let doubles = gaps.filter { $0 < 1 }
        #expect(doubles.count == 1)
        for gap in gaps where gap >= 1 { #expect(gap >= 3 && gap <= 5.1) }
        // 깜빡임은 약 0.2초, 잎과 숨은 작고 느리다.
        #expect(abs(SaessagiIdleMotion.blinkClose + SaessagiIdleMotion.blinkOpen - 0.2) < 0.05)
        // 깜빡임은 약 0.2초. 잎과 숨은 작은 크기에서도 보일 만큼, 그러나 과하지 않게.
        #expect(SaessagiIdleMotion.leafAngle >= 4 && SaessagiIdleMotion.leafAngle <= 8)
        #expect(SaessagiIdleMotion.breathStretch >= 0.03 && SaessagiIdleMotion.breathStretch <= 0.05)
        #expect(SaessagiIdleMotion.leafHalfPeriod >= 1 && SaessagiIdleMotion.breathHalfPeriod >= 1.2)

        // 키프레임: 시간은 0에서 1까지 늘어나고, 눈은 뜬 채로 시작해 뜬 채로 끝난다.
        let track = SaessagiIdleMotion.blinkTrack
        #expect(track.values.count == track.keyTimes.count)
        #expect(track.keyTimes.first == 0 && track.keyTimes.last == 1)
        #expect(zip(track.keyTimes.dropFirst(), track.keyTimes).allSatisfy { $0 > $1 })
        #expect(track.values.first == 1 && track.values.last == 1)
        #expect(track.values.filter { $0 == SaessagiIdleMotion.closedEyeScale }.count == starts.count)
    }

    // MARK: - 걷기

    @Test func walkIsUnhurriedAndPlantedFeetDoNotSlide() throws {
        let size = 48.0
        for (from, to) in [(0.0, 24.0), (30.0, 6.0), (10.0, 13.0)] {
            let plan = try #require(SaessagiMotionPlan.walk(from: from, to: to, size: size))
            let direction = to > from ? 1.0 : -1.0
            #expect(plan.steps >= 2 && plan.steps <= SaessagiWalkMotion.maximumSteps)
            // 처음 자리에서 출발해 정확히 그 자리에 선다. 중간에 범위를 벗어나지 않는다.
            #expect(plan.position(at: 0) == from && abs(plan.finalX - to) < 1e-9)
            #expect(plan.moverX.values.allSatisfy { $0 >= min(from, to) - 1e-9 && $0 <= max(from, to) + 1e-9 })
            // 걸음마다 디딘 발이 땅에서 제자리에 있다: 몸의 위치 + 몸에 대한 발의 위치가 걸음 내내 같다.
            let period = SaessagiWalkMotion.stepDuration
            // 가는 쪽을 보기 시작하고 조금 뒤에 첫발을 뗀다.
            let first = SaessagiWalkMotion.faceTurn * 0.6
            for index in 0..<plan.steps {
                let begin = first + Double(index) * period
                let swingsRight = (direction > 0) == (index % 2 == 0)
                let stance = swingsRight ? plan.footLeftX : plan.footRightX
                let stanceLift = swingsRight ? plan.footLeftLift : plan.footRightLift
                let swingLift = swingsRight ? plan.footRightLift : plan.footLeftLift
                let planted = plan.moverX.value(at: begin) + stance.value(at: begin)
                for fraction in [0.25, 0.5, 0.75, 1.0] {
                    let time = begin + period * fraction
                    #expect(abs(plan.moverX.value(at: time) + stance.value(at: time) - planted) < 1e-6)
                    #expect(abs(stanceLift.value(at: time)) < 1e-6)
                }
                #expect(abs(swingLift.value(at: begin + period / 2) - SaessagiWalkMotion.footLift * size) < 1e-6)
            }
            // 가는 쪽을 보고, 끝나면 모두 평소 자세다.
            #expect(plan.face.value(at: plan.duration / 2) * direction > 0)
            for track in [plan.bob, plan.footLeftX, plan.footLeftLift, plan.footRightX, plan.footRightLift, plan.rock, plan.leaf, plan.face] {
                #expect(abs(track.last) < 1e-9 && track.values[0] == 0)
            }
            #expect(plan.squashX.isConstant && plan.squashY.isConstant && plan.eyes.isConstant)
        }
        // 1초에 서너 걸음, 한 번 걷는 데 길어야 3초쯤.
        #expect(1 / SaessagiWalkMotion.stepDuration >= 3 && 1 / SaessagiWalkMotion.stepDuration <= 4)
        let longest = try #require(SaessagiMotionPlan.walk(from: 0, to: 500, size: size))
        #expect(longest.steps == SaessagiWalkMotion.maximumSteps && longest.duration <= 3.1 && longest.duration >= 2)
        #expect(SaessagiMotionPlan.walk(from: 5, to: 5.2, size: size) == nil)
    }

    @Test func walkTargetsStayInsideTheLane() {
        var generator = SystemRandomNumberGenerator()
        let size = 48.0, range = 60.0
        let step = SaessagiWalkMotion.stepLength * size
        for start in [0.0, 12.0, 31.0, 60.0] {
            for _ in 0..<60 {
                guard let target = SaessagiMotionPlan.walkTarget(from: start, range: range, size: size, using: &generator) else {
                    Issue.record("자리가 60pt면 어디서든 걸을 수 있다")
                    continue
                }
                #expect(target >= 0 && target <= range)
                let distance = abs(target - start)
                #expect(distance >= Double(SaessagiWalkMotion.minimumSteps - 1) * step - 1e-9)
                #expect(distance <= Double(SaessagiWalkMotion.maximumSteps - 1) * step + 1e-9)
            }
        }
        // 걸을 자리가 없으면 걷지 않는다.
        #expect(SaessagiMotionPlan.walkTarget(from: 0, range: 0, size: size, using: &generator) == nil)
        #expect(SaessagiMotionPlan.walkTarget(from: 2, range: 6, size: size, using: &generator) == nil)
    }

    // MARK: - 다른 행동

    @Test func stationaryActionsStayPutAndReturnToTheRestingPose() {
        let size = 48.0
        let plans: [(SaessagiMotionPlan, ClosedRange<Double>)] = [
            (.lookAround(at: 17, size: size), 1.0...2.0),
            (.hop(at: 17, size: size), 0.8...1.3),
            (.doze(at: 17, size: size), 2.0...3.0),
        ]
        for (plan, length) in plans {
            #expect(length.contains(plan.duration))
            // 제자리에서 한다.
            #expect(plan.moverX.isConstant && plan.finalX == 17 && plan.steps == 0)
            // 끝나면 평소 자세로 돌아와 있다.
            for track in [plan.bob, plan.footLeftX, plan.footLeftLift, plan.footRightX, plan.footRightLift, plan.rock, plan.leaf, plan.face] {
                #expect(abs(track.last) < 1e-9 && track.values[0] == 0)
                #expect(abs(track.end - plan.duration) < 1e-9)
            }
            for track in [plan.squashX, plan.squashY, plan.eyes] {
                #expect(track.last == 1 && track.values[0] == 1)
                // 찌그러질 만큼 눌리거나 늘어나지 않는다.
                #expect(track.values.allSatisfy { $0 >= 0.08 && $0 <= 1.2 })
            }
            #expect(plan.squashX.values.allSatisfy { $0 >= 0.9 && $0 <= 1.12 })
            #expect(plan.squashY.values.allSatisfy { $0 >= 0.85 && $0 <= 1.1 })
            #expect(plan.rock.values.allSatisfy { abs($0) <= 10 })
        }
        // 두리번: 왼쪽을 먼저, 그다음 오른쪽.
        let look = SaessagiMotionPlan.lookAround(at: 0, size: size)
        #expect(look.face.value(at: 0.5) < 0 && look.face.value(at: 1.2) > 0)
        // 폴짝: 뜨기 전에 움츠리고, 내려앉으며 눌린다. 발밑으로 꺼지지는 않는다.
        let hop = SaessagiMotionPlan.hop(at: 0, size: size)
        #expect(hop.bob.values.allSatisfy { $0 >= 0 } && hop.bob.values.max() == 0.2 * size)
        #expect(hop.squashY.value(at: 0.14) < 1 && hop.squashY.value(at: 0.64) < 0.95)
        // 졸기: 눈을 감고 있다가 번쩍 뜬다.
        let doze = SaessagiMotionPlan.doze(at: 0, size: size)
        #expect(doze.eyes.value(at: 1.5) == SaessagiIdleMotion.closedEyeScale && doze.eyes.value(at: 2.2) > 1)
    }

    @Test func todayBehaviourMixesActionsAndNeverRepeatsBackToBack() {
        var generator = SystemRandomNumberGenerator()
        var counts: [SaessagiAction: Int] = [:]
        var last: SaessagiAction?
        let behavior = SaessagiBehavior.today
        for _ in 0..<4_000 {
            let action = behavior.next(after: last, using: &generator)
            #expect(action != last && action.isAvailable)
            counts[action, default: 0] += 1
            last = action
        }
        // 네 가지 행동과 쉬기가 모두 나오고, 그 밖의 동작은 나오지 않는다.
        for action in [SaessagiAction.stay, .walk, .lookAround, .hop, .doze] { #expect((counts[action] ?? 0) > 200) }
        #expect(counts.count == 5)
        // 조는 것이 걷기·두리번거리기보다 드물다.
        #expect(counts[.doze]! < counts[.walk]! && counts[.doze]! < counts[.lookAround]!)
        // 10초쯤 보면 여러 번 움직인다: 쉬는 시간은 2~5초.
        #expect(behavior.rest == 2.0...5.0 && behavior.firstRest <= 3)
    }

    @Test func everyPoseHasABehaviourThatSuitsIt() {
        var generator = SystemRandomNumberGenerator()
        for pose in SaessagiPose.allCases {
            let behavior = SaessagiBehavior.standard(for: pose)
            #expect(!behavior.choices.isEmpty)
            #expect(behavior.rest.upperBound <= 6 && behavior.rest.lowerBound > 0)
            // 그림 한 장짜리 모습은 나뉜 레이어가 있어야 하는 행동을 고르지 않는다.
            if pose != .idle {
                #expect(behavior.choices.allSatisfy { !$0.action.needsLayers })
            }
            // 숨은 작고 느리다.
            #expect(behavior.breathStretch <= 0.05 && behavior.breathHalfPeriod >= 1.2)
            for _ in 0..<20 { #expect(behavior.next(after: nil, using: &generator).isAvailable) }
        }
        // 쉬는 모습과 자는 모습은 숨이 더 느리다.
        #expect(SaessagiBehavior.resting.breathHalfPeriod > SaessagiBehavior.today.breathHalfPeriod)
        #expect(SaessagiBehavior.sleeping.breathHalfPeriod >= SaessagiBehavior.resting.breathHalfPeriod)
        // 축하는 평소의 응원보다 잦다.
        #expect(SaessagiBehavior.celebrating.rest.upperBound < SaessagiBehavior.cheering.rest.upperBound)
        #expect(SaessagiBehavior.celebrating.choices.contains { $0.action == .cheer })
        // 고를 것이 하나뿐이면 그것을 다시 한다. 고를 것이 없으면 쉰다.
        #expect(SaessagiBehavior.joyful.next(after: .bounce, using: &generator) == .bounce)
        #expect(SaessagiBehavior.calm.next(after: nil, using: &generator) == .stay)
    }

    @Test func wholeImageActionsStayGentleAndEndAtRest() throws {
        var generator = SystemRandomNumberGenerator()
        let size = 52.0
        for action in [SaessagiAction.sway, .bounce, .cheer, .wave, .wiggle, .deepBreath] {
            let plan = try #require(SaessagiMotionPlan.make(action, at: 0, range: 0, size: size, using: &generator))
            #expect(plan.duration >= 0.6 && plan.duration <= 3.1)
            // 제자리에서, 그림 전체만 움직인다(발·눈·입·잎을 따로 건드리지 않는다).
            #expect(plan.moverX.isConstant && plan.finalX == 0)
            for track in [plan.footLeftX, plan.footLeftLift, plan.footRightX, plan.footRightLift, plan.leaf, plan.face] {
                #expect(track.isConstant)
            }
            #expect(plan.eyes.isConstant)
            // 끝나면 평소 자세.
            #expect(abs(plan.bob.last) < 1e-9 && abs(plan.rock.last) < 1e-9)
            #expect(plan.squashX.last == 1 && plan.squashY.last == 1)
            // 작은 카드 안에서도 자리를 크게 벗어나지 않는다: 뜀은 키의 15%까지, 기울기는 8도까지, 눌림은 10%쯤까지.
            #expect(plan.bob.values.allSatisfy { $0 >= 0 && $0 <= 0.15 * size + 1e-9 })
            #expect(plan.rock.values.allSatisfy { abs($0) <= 8 })
            #expect(plan.squashX.values.allSatisfy { $0 >= 0.95 && $0 <= 1.08 })
            #expect(plan.squashY.values.allSatisfy { $0 >= 0.9 && $0 <= 1.06 })
        }
        // 쉬기와 아직 없는 동작은 움직임을 만들지 않는다. 걸을 자리가 없으면 걷지 않는다.
        for action in [SaessagiAction.stay, .tumble, .peek, .walk] {
            #expect(SaessagiMotionPlan.make(action, at: 0, range: 0, size: size, using: &generator) == nil)
        }
        // 축하는 두 번 뛴다.
        let cheer = SaessagiMotionPlan.cheer(at: 0, size: size)
        #expect(cheer.bob.values.filter { $0 == 0.15 * size }.count == 2)
    }

    @Test func rigsAreLayeredOnlyForTheIdlePose() throws {
        for pose in SaessagiPose.allCases {
            let rig = try #require(SaessagiRig(pose: pose, size: 48, displayScale: 2))
            #expect(rig.isLayered == (pose == .idle))
            #expect(rig.pose == pose)
            #expect(rig.body.width == Int((48 + SaessagiRenderer.padding * 2) * 2))
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
