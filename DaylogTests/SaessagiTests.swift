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

    /// 걸음마다 디딘 발이 땅에서 제자리에 있는지 본다: 몸의 위치 + 몸에 대한 발의 위치가 걸음 내내 같아야 한다.
    private func expectNoSliding(_ plan: SaessagiWalkPlan, legStart: Double, steps: Int, direction: Double) {
        let period = SaessagiWalkMotion.stepDuration
        for index in 0..<steps {
            let begin = legStart + Double(index) * period
            let swingsRight = (direction > 0) == (index % 2 == 0)
            let stance = swingsRight ? plan.footLeftX : plan.footRightX
            let stanceLift = swingsRight ? plan.footLeftLift : plan.footRightLift
            let swingLift = swingsRight ? plan.footRightLift : plan.footLeftLift
            let planted = plan.moverX.value(at: begin) + stance.value(at: begin)
            for fraction in [0.25, 0.5, 0.75, 1.0] {
                let time = begin + period * fraction
                #expect(abs(plan.moverX.value(at: time) + stance.value(at: time) - planted) < 1e-6)
                // 디딘 발은 땅에 붙어 있다.
                #expect(abs(stanceLift.value(at: time)) < 1e-6)
            }
            // 든 발은 걸음 한가운데에서 가장 높다.
            #expect(abs(swingLift.value(at: begin + period / 2) - SaessagiWalkMotion.footLift * 48) < 1e-6)
        }
    }

    @Test func walkGoesOutTurnsAndComesBackWithoutSliding() throws {
        let size = 48.0, range = 60.0
        let plan = try #require(SaessagiWalkPlan.roundTrip(range: range, size: size))
        let step = SaessagiWalkMotion.stepLength * size
        let steps = plan.stepsPerLeg
        #expect(steps >= SaessagiWalkMotion.minimumSteps && steps <= SaessagiWalkMotion.maximumSteps)
        let legTime = Double(steps) * SaessagiWalkMotion.stepDuration
        let far = Double(steps - 1) * step
        // 자리를 벗어나지 않는다: 0에서 가장 먼 곳까지, 그리고 제자리로.
        #expect(far <= range + 1e-9 && far > range - step * 2)
        #expect(plan.moverX.values.allSatisfy { $0 >= -1e-9 && $0 <= far + 1e-9 })
        #expect(abs(plan.position(at: legTime) - far) < 1e-9)
        #expect(abs(plan.position(at: legTime + SaessagiWalkMotion.turnPause) - far) < 1e-9)
        #expect(abs(plan.position(at: plan.duration)) < 1e-9 && plan.position(at: 0) == 0)
        // 가는 길과 오는 길 모두 디딘 발이 미끄러지지 않는다.
        expectNoSliding(plan, legStart: 0, steps: steps, direction: 1)
        expectNoSliding(plan, legStart: legTime + SaessagiWalkMotion.turnPause, steps: steps, direction: -1)
        // 가는 쪽을 본다: 갈 때는 오른쪽, 돌아서고 나서는 왼쪽, 끝나면 앞.
        #expect(plan.face.value(at: legTime * 0.5) > 0)
        #expect(plan.face.value(at: legTime + SaessagiWalkMotion.turnPause + legTime * 0.5) < 0)
        // 끝나면 모든 것이 평소 자세다.
        for track in [plan.bob, plan.footLeftX, plan.footLeftLift, plan.footRightX, plan.footRightLift, plan.rock, plan.leaf, plan.face] {
            #expect(abs(track.last) < 1e-9 && track.values[0] == 0)
            #expect(abs(track.end - plan.duration) < 1e-9)
            #expect(zip(track.times.dropFirst(), track.times).allSatisfy { $0 > $1 })
        }
        // 몸은 걸음마다 한 번씩 뜨고, 좌우로 번갈아 기운다.
        #expect(plan.bob.values.max() == SaessagiWalkMotion.bob * size && plan.bob.values.min() == 0)
        let period = SaessagiWalkMotion.stepDuration
        let first = plan.rock.value(at: period * 0.5) - SaessagiWalkMotion.lean
        let second = plan.rock.value(at: period * 1.5) - SaessagiWalkMotion.lean
        #expect(first * second < 0)
    }

    @Test func walkNeedsRoomAndReturnsHomeFromAnywhere() throws {
        // 걸을 자리가 없으면 걷지 않는다.
        #expect(SaessagiWalkPlan.roundTrip(range: 0, size: 48) == nil)
        #expect(SaessagiWalkPlan.roundTrip(range: 4, size: 48) == nil)
        // 자리가 넓어도 걸음 수에는 상한이 있다.
        #expect(SaessagiWalkPlan.roundTrip(range: 2_000, size: 48)?.stepsPerLeg == SaessagiWalkMotion.maximumSteps)
        // 떨어져 있던 자리에서는 딱 그만큼을 걸어 제자리로 온다.
        for away in [3.0, 17.3, 55.0] {
            let plan = try #require(SaessagiWalkPlan.returnHome(from: away, size: 48))
            #expect(plan.position(at: 0) == away && abs(plan.position(at: plan.duration)) < 1e-9)
            #expect(plan.moverX.values.allSatisfy { $0 >= -1e-9 && $0 <= away + 1e-9 })
            expectNoSlidingReturn(plan)
        }
        #expect(SaessagiWalkPlan.returnHome(from: 0, size: 48) == nil)
    }

    private func expectNoSlidingReturn(_ plan: SaessagiWalkPlan) {
        let period = SaessagiWalkMotion.stepDuration
        for index in 0..<plan.stepsPerLeg {
            let begin = Double(index) * period
            // 왼쪽으로 갈 때는 왼발부터 내딛는다.
            let stance = index % 2 == 0 ? plan.footRightX : plan.footLeftX
            let planted = plan.moverX.value(at: begin) + stance.value(at: begin)
            #expect(abs(plan.moverX.value(at: begin + period) + stance.value(at: begin + period) - planted) < 1e-6)
        }
    }

    @Test func onlyWalkingIsAvailableForNow() {
        var generator = SystemRandomNumberGenerator()
        #expect(SaessagiAction.allCases.filter(\.isAvailable) == [.walk])
        for _ in 0..<20 { #expect(SaessagiAction.next(using: &generator) == .walk) }
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
