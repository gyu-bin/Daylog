import CoreGraphics
import Testing
@testable import Daylog

/// 휴가 화면의 해먹 장면: 조각의 자리와, 새싹이가 가끔 하는 행동의 박자표.
@MainActor
struct VacationSceneTests {
    private func layout(pane: CGSize, side: CGFloat, top: CGFloat = 200) -> VacationSceneLayout {
        let height = side * VacationArt.slotHeight / VacationArt.canvas
        return VacationSceneLayout(pane: pane, slot: CGRect(x: (pane.width - side) / 2, y: top, width: side, height: height))
    }

    // MARK: - 자리

    @Test func palmsStandSymmetricallyBehindThePostsAndInTheSand() {
        // 두 나무는 해먹의 가운데를 두고 대칭이다.
        let left = VacationArt.palmRect(VacationArt.palmTrunk(.left), side: .left)
        let right = VacationArt.palmRect(VacationArt.palmTrunk(.right), side: .right)
        #expect(abs((left.minX + right.maxX) / 2 - VacationArt.canvas / 2) < 0.5)
        #expect(left.minY == right.minY && left.height == right.height)
        // 나무 꼭대기는 해먹 기둥(x 47~110, 914~977)의 바깥쪽에 있다.
        let leftCrown = VacationArt.palmOrigin(.left).x + VacationArt.palmFronds(.left).pivot!.x * VacationArt.palmScale
        let rightCrown = VacationArt.palmOrigin(.right).x + VacationArt.palmFronds(.right).pivot!.x * VacationArt.palmScale
        #expect(leftCrown < 47 && rightCrown > 977)
        // 밑동은 모래선 아래로 묻히고, 해먹은 모래선보다 조금 아래까지 내려온다.
        #expect(left.maxY > VacationArt.sandLine)
        #expect(VacationArt.slotTop + VacationArt.slotHeight > VacationArt.sandLine)
        // 두 나무의 그림 캔버스까지가 장면의 너비다.
        let width = VacationArt.palmOrigin(.right).x + 1024 * VacationArt.palmScale - VacationArt.palmOrigin(.left).x
        #expect(abs(width - VacationArt.rigWidthRatio * VacationArt.canvas) < 0.5)
    }

    @Test func pivotsAndOverlaysLieInsideTheHammock() {
        for piece in [VacationArt.leaf, VacationArt.palmFronds(.left), VacationArt.palmFronds(.right)] {
            let anchor = piece.anchor
            #expect((0...1).contains(anchor.x) && (0...1).contains(anchor.y), "\(piece.asset)")
        }
        // 손 그림과 잎은 해먹 그림 안에 있고, 손 그림은 잎과 겹치지 않는다(겹치면 멈춘 잎이 하나 더 보인다).
        for piece in [VacationArt.leaf, VacationArt.sipHands, VacationArt.adjustHands] {
            #expect(VacationArt.hammock.rect.contains(piece.rect), "\(piece.asset)")
        }
        #expect(VacationArt.sipHands.rect.maxX <= VacationArt.leaf.rect.minX + 12)
        #expect(VacationArt.adjustHands.rect.maxX <= VacationArt.leaf.rect.minX)
        // 줄이 묶인 높이는 해먹 자리 안에 있다.
        #expect(VacationArt.hookLine > VacationArt.slotTop && VacationArt.hookLine < VacationArt.sandLine)
    }

    @Test func sceneryFollowsTheHammockAndCoversThePane() {
        // iPhone: 풍경 한 장이 화면을 덮는다.
        let phone = layout(pane: CGSize(width: 402, height: 780), side: 360)
        #expect(phone.sceneryTilesPerSide == 0)
        #expect(phone.sceneryFrame.minX <= 0 && phone.sceneryFrame.maxX >= 402)
        // 모래선은 해먹 자리 안, 나무 밑동 높이에 온다.
        #expect(phone.sandY > phone.slot.minY && phone.sandY < phone.slot.maxY)
        #expect(abs(phone.sandY - (phone.poseOrigin.y + VacationArt.sandLine * phone.unit)) < 1e-6)
        // 하늘은 산 뒤에서 끝나고, 모래는 풍경 아래에서 화면 끝까지 간다.
        #expect(phone.skyFrame.maxY > phone.sceneryFrame.minY && phone.skyFrame.maxY < phone.sandY)
        #expect(phone.sandFrame.minY < phone.sceneryFrame.maxY && phone.sandFrame.maxY == 780)

        // 넓은 창: 풍경이 해먹보다 지나치게 커지지 않고, 모자란 너비는 양옆에 이어 붙인다.
        let wide = layout(pane: CGSize(width: 1400, height: 760), side: 500)
        #expect(wide.sceneryWidth == 500 * 1.55)
        #expect(wide.sceneryTilesPerSide == 1)
        let covered = wide.sceneryWidth * CGFloat(wide.sceneryTilesPerSide * 2 + 1)
        #expect(covered >= 1400)
        // 산은 해먹 자리 위로 올라가지 않는다(그 위는 문구가 있는 하늘이다).
        #expect(wide.peaksY >= wide.slot.minY)
    }

    @Test func sunAndCloudsStayInTheSkyBelowTheTopInset() {
        var layout = layout(pane: CGSize(width: 402, height: 780), side: 360, top: 260)
        layout.topInset = 59
        #expect(layout.sunFrame.midY > 59 && layout.sunFrame.midY < layout.peaksY)
        #expect(layout.sunFrame.midX > 402 / 2)
        for cloud in VacationArt.clouds {
            let frame = layout.cloudFrame(cloud)
            #expect(frame.midY > 59 && frame.midY < layout.peaksY)
        }
    }

    @Test func hammockSizeLeavesRoomForTextAndButtons() {
        // 좁은 화면: 너비에 맞춘다.
        #expect(VacationArt.hammockSide(pane: CGSize(width: 402, height: 780), reserved: 300) == 402 * 0.95)
        // 낮은 화면: 문구와 단추의 높이를 남긴다.
        let low = VacationArt.hammockSide(pane: CGSize(width: 1000, height: 700), reserved: 400)
        #expect(abs(low * VacationArt.slotHeight / VacationArt.canvas - 300) < 0.01)
        // 너무 작아지지도, 너무 커지지도 않는다.
        #expect(VacationArt.hammockSide(pane: CGSize(width: 900, height: 420), reserved: 400) == 210)
        #expect(VacationArt.hammockSide(pane: CGSize(width: 2000, height: 2000), reserved: 400) == 720)
    }

    // MARK: - 행동

    @Test func neverRepeatsTheSameActionAndDoesThemAll() {
        var generator = SystemRandomNumberGenerator()
        var last: VacationAction?
        var seen = Set<VacationAction>()
        for _ in 0..<300 {
            let next = VacationAction.next(after: last, using: &generator)
            #expect(next != last)
            seen.insert(next)
            last = next
        }
        #expect(seen == Set(VacationAction.allCases))
    }

    @Test func everyActionReturnsToTheRestingPose() {
        for action in VacationAction.allCases {
            let plan = VacationMotionPlan.make(action)
            for path in VacationMotionPlan.tracks {
                let track = plan[keyPath: path]
                // 모든 값이 행동의 길이만큼 이어져 있어야 키프레임의 시간이 서로 맞는다.
                #expect(abs(track.end - plan.duration) < 1e-9, "\(action)")
                #expect(track.times == track.times.sorted())
                // 끝나면 손 그림은 사라지고 잎과 해먹은 제자리다.
                #expect(track.last == 0, "\(action)")
            }
        }
    }

    @Test func sipShowsTheDrinkThenRestsSatisfied() {
        let plan = VacationMotionPlan.sip()
        #expect(plan.sipOpacity.value(at: 0.1) == 0)
        #expect(plan.sipOpacity.value(at: 1.5) == 1)
        #expect(plan.sipOpacity.value(at: 3) == 0)
        // 다 마시고 손을 내린 뒤에 한숨 돌린다(해먹이 조금 더 내려앉는다).
        #expect(plan.stretch.value(at: 2.6) == 0 && plan.stretch.value(at: 3.6) > 0.01)
        // 다른 손은 나오지 않는다.
        #expect(plan.adjustOpacity.isConstant)
    }

    @Test func adjustShowsOnlyTheSunglassesHand() {
        let plan = VacationMotionPlan.adjust()
        #expect(plan.adjustOpacity.value(at: 0.1) == 0)
        #expect(plan.adjustOpacity.value(at: 1.0) == 1)
        #expect(plan.adjustOpacity.value(at: 2.4) == 0)
        #expect(plan.sipOpacity.isConstant && plan.stretch.isConstant)
    }

    @Test func handsSwapQuicklyAndNeverOverlap() {
        // 두 손 그림이 한꺼번에 보이는 행동은 없다.
        for action in VacationAction.allCases {
            let plan = VacationMotionPlan.make(action)
            for step in 0...Int(plan.duration * 100) {
                let time = Double(step) / 100
                #expect(plan.sipOpacity.value(at: time) == 0 || plan.adjustOpacity.value(at: time) == 0)
            }
        }
        #expect(VacationMotionPlan.swap <= 0.3)
    }
}
