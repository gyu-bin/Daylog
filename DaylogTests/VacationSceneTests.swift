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

    @Test func palmsStandSymmetricallyUnderTheKnotsAndInTheSand() {
        // 두 나무는 해먹의 가운데를 두고 대칭이다.
        let left = VacationArt.palmRect(VacationArt.palmTrunk(.left), side: .left)
        let right = VacationArt.palmRect(VacationArt.palmTrunk(.right), side: .right)
        #expect(abs((left.minX + right.maxX) / 2 - VacationArt.canvas / 2) < 0.5)
        #expect(left.minY == right.minY && left.height == right.height)
        // 나무 꼭대기(잎의 중심)는 줄의 매듭(86, 940) 바로 아래다.
        let leftCrown = VacationArt.palmOrigin(.left).x + VacationArt.palmFronds(.left).pivot!.x * VacationArt.palmScale
        let rightCrown = VacationArt.palmOrigin(.right).x + VacationArt.palmFronds(.right).pivot!.x * VacationArt.palmScale
        #expect(abs(leftCrown - 86) < 8 && abs(rightCrown - 940) < 8)
        #expect(VacationArt.palmOrigin(.left).y + 390 * VacationArt.palmScale > VacationArt.hookLine)
        // 밑동은 모래선 아래로 묻힌다.
        #expect(left.maxY > VacationArt.sandLine)
        // 두 나무의 그림 캔버스까지가 장면의 너비다.
        let width = VacationArt.palmOrigin(.right).x + 1024 * VacationArt.palmScale - VacationArt.palmOrigin(.left).x
        #expect(abs(width - VacationArt.rigWidthRatio * VacationArt.canvas) < 0.5)
    }

    @Test func pivotsLieInsideTheirPieces() {
        for piece in [VacationArt.leaf, VacationArt.drink, VacationArt.armSip, VacationArt.armAdjust,
                      VacationArt.palmFronds(.left), VacationArt.palmFronds(.right)] {
            let anchor = piece.anchor
            #expect((0...1).contains(anchor.x) && (0...1).contains(anchor.y), "\(piece.asset)")
        }
        #expect(VacationArt.body.anchor == CGPoint(x: 0.5, y: 0.5))
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
            }
            // 끝나면 잔·손·선글라스·잎·숨이 모두 제자리다.
            for path in [\VacationMotionPlan.drinkX, \.drinkY, \.drinkTilt, \.handRestX, \.handRestY, \.glassesY, \.glassesTilt, \.leaf, \.stretch] {
                #expect(plan[keyPath: path].last == 0, "\(action)")
            }
            #expect(plan.handRestOpacity.last == 1 && plan.armSipOpacity.last == 0 && plan.armAdjustOpacity.last == 0)
        }
    }

    @Test func sipKeepsAHandOnTheGlassAllTheWay() {
        let plan = VacationMotionPlan.sip()
        // 잔은 받은 "마시는 자세"의 자리까지 간다.
        #expect(plan.drinkX.value(at: 0.9) == Double(VacationArt.sipOffset.width))
        #expect(plan.drinkY.value(at: 0.9) == Double(VacationArt.sipOffset.height))
        #expect(plan.drinkTilt.value(at: 0.9) == VacationArt.sipTilt)
        // 어느 순간에도 쉬던 손이나 마시는 팔 가운데 하나는 보인다(잔이 혼자 떠 있지 않다).
        for step in 0...520 {
            let time = Double(step) / 100
            #expect(plan.handRestOpacity.value(at: time) + plan.armSipOpacity.value(at: time) >= 0.999)
        }
        // 잔이 입가에 있는 동안에는 마시는 팔만 보이고, 쉬던 손은 그 팔의 손 자리에 가 있다.
        #expect(plan.armSipOpacity.value(at: 1.5) == 1 && plan.handRestOpacity.value(at: 1.5) == 0)
        #expect(plan.handRestX.value(at: 1.5) == Double(VacationArt.sipHandOffset.width))
        // 마신 뒤에는 잔을 내려놓고 나서 한숨 돌린다.
        #expect(plan.stretch.value(at: 3.4) == 0 && plan.stretch.value(at: 4.1) > 0.03)
        // 다른 팔과 선글라스는 가만히 있다.
        #expect(plan.armAdjustOpacity.isConstant && plan.glassesY.isConstant)
    }

    @Test func adjustTouchesTheSunglassesOnlyWhileTheArmIsUp() {
        let plan = VacationMotionPlan.adjust()
        #expect(plan.glassesY.value(at: 0.4) == 0)
        #expect(plan.armAdjustOpacity.value(at: 0.45) == 1)
        #expect(plan.glassesY.value(at: 0.8) < 0 && plan.glassesTilt.value(at: 0.8) < 0)
        // 선글라스가 제자리에 온 뒤에 팔이 내려간다.
        #expect(plan.glassesY.value(at: 1.75) == 0 && plan.armAdjustOpacity.value(at: 1.9) == 1)
        // 잔은 건드리지 않는다.
        #expect(plan.drinkX.isConstant && plan.handRestOpacity.isConstant && plan.armSipOpacity.isConstant)
    }
}
