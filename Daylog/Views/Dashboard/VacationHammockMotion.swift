import Foundation

/// 해먹 위의 새싹이가 가끔 하는 행동. 늘 도는 움직임(해먹의 흔들림, 숨쉬기, 잎의 살랑임)과 따로, 한 번에 하나만 한다.
enum VacationAction: CaseIterable, Sendable {
    /// 음료를 입으로 가져가 마시고, 내려놓은 뒤 만족스럽게 한숨 돌린다.
    case sip
    /// 선글라스를 살짝 고쳐 쓴다.
    case adjust
    /// 바람이 지나가 잎이 크게 살랑인다.
    case flutter
    /// 깊게 숨을 쉬며 몸을 편다.
    case sigh

    /// 고를 때의 비중. 마시기가 가장 잦다.
    var weight: Int {
        switch self {
        case .sip: return 4
        case .adjust: return 3
        case .flutter: return 2
        case .sigh: return 1
        }
    }

    /// 처음 행동까지 기다리는 시간(초)과, 행동 사이에 가만히 쉬는 시간.
    static let firstRest: Double = 2.4
    static let rest: ClosedRange<Double> = 3.5...6.5

    /// 다음 행동. 같은 행동을 잇달아 하지 않는다.
    static func next(after last: VacationAction?, using generator: inout some RandomNumberGenerator) -> VacationAction {
        let candidates = allCases.filter { $0 != last }
        var pick = Int.random(in: 0..<candidates.reduce(0) { $0 + $1.weight }, using: &generator)
        for candidate in candidates {
            if pick < candidate.weight { return candidate }
            pick -= candidate.weight
        }
        return candidates[candidates.count - 1]
    }
}

/// 행동 한 번의 전체 움직임. 거리는 포즈 단위(1024 기준, 오른쪽과 아래가 양수), 기울기는 도(시계 방향이 양수), 불투명도는 0…1이다.
///
/// 잔·손·팔은 같은 박자표를 따른다: 잔이 움직이는 동안 쉬던 손이 잔을 받치고 따라가고, 잔이 입가에 닿을 때 마시는 팔로 바뀐다.
/// 그래서 잔이 혼자 떠다니는 순간이 없다. 행동이 끝나면 모든 값이 쉬는 자세로 돌아온다.
struct VacationMotionPlan: Equatable, Sendable {
    var duration: Double
    var drinkX = SaessagiTrack()
    var drinkY = SaessagiTrack()
    var drinkTilt = SaessagiTrack()
    var handRestX = SaessagiTrack()
    var handRestY = SaessagiTrack()
    var handRestOpacity = SaessagiTrack(start: 1)
    var armSipOpacity = SaessagiTrack()
    var armAdjustOpacity = SaessagiTrack()
    var armAdjustX = SaessagiTrack()
    var armAdjustY = SaessagiTrack()
    var glassesY = SaessagiTrack()
    var glassesTilt = SaessagiTrack()
    /// 늘 도는 잎의 살랑임 위에 더하는 기울기.
    var leaf = SaessagiTrack()
    /// 늘 도는 숨쉬기 위에 더하는 키(1에 더하는 값).
    var stretch = SaessagiTrack()

    static func make(_ action: VacationAction) -> VacationMotionPlan {
        switch action {
        case .sip: return sip()
        case .adjust: return adjust()
        case .flutter: return flutter()
        case .sigh: return sigh()
        }
    }

    /// 쉬던 손과 마시는 팔이 서로 바뀌는 데 걸리는 시간(초).
    static let handSwap = 0.12

    /// 마시기: 잔을 들고(0.9초) → 두 모금(1.6초) → 내려놓고(0.9초) → 만족스럽게 한숨 돌린다(1.8초).
    static func sip() -> VacationMotionPlan {
        var plan = VacationMotionPlan(duration: 5.2)
        let lifted = 0.9, sipped = 2.5, lowered = 3.4
        let offset = VacationArt.sipOffset, hand = VacationArt.sipHandOffset, tilt = VacationArt.sipTilt

        // 잔: 쉬는 자리 → 입가 → 쉬는 자리.
        plan.drinkX.add(Double(offset.width), at: lifted)
        plan.drinkY.add(Double(offset.height), at: lifted)
        plan.drinkTilt.add(tilt, at: lifted)
        plan.drinkX.hold(until: sipped)
        plan.drinkY.hold(until: sipped)
        // 두 모금: 잔을 조금 더 기울였다가 세운다.
        for (time, value) in [(1.3, tilt + 6), (1.7, tilt + 1), (2.1, tilt + 6), (sipped, tilt)] { plan.drinkTilt.add(value, at: time) }
        plan.drinkX.add(0, at: lowered)
        plan.drinkY.add(0, at: lowered)
        plan.drinkTilt.add(0, at: lowered)

        // 쉬던 손: 잔을 따라 올라가다 마시는 팔로 바뀌고, 내려올 때 다시 나타나 제자리로 간다.
        plan.handRestX.add(Double(hand.width), at: lifted)
        plan.handRestY.add(Double(hand.height), at: lifted)
        plan.handRestX.hold(until: sipped)
        plan.handRestY.hold(until: sipped)
        plan.handRestX.add(0, at: lowered)
        plan.handRestY.add(0, at: lowered)
        // 두 손이 겹쳐 비쳐 보이는 시간이 짧도록 빠르게 바꾼다.
        plan.handRestOpacity.hold(until: lifted - Self.handSwap)
        plan.handRestOpacity.add(0, at: lifted)
        plan.handRestOpacity.hold(until: sipped)
        plan.handRestOpacity.add(1, at: sipped + Self.handSwap)
        plan.armSipOpacity.hold(until: lifted - Self.handSwap)
        plan.armSipOpacity.add(1, at: lifted)
        plan.armSipOpacity.hold(until: sipped)
        plan.armSipOpacity.add(0, at: sipped + Self.handSwap)

        // 모금마다 잎이 살짝 들리고, 다 마신 뒤에는 한숨 돌리며 기분 좋게 흔든다.
        for (time, value) in [(1.1, 0.0), (1.3, -5), (1.7, 0), (2.1, -5), (sipped, 0), (lowered, 0)] { plan.leaf.add(value, at: time) }
        for (time, value) in [(3.8, 8.0), (4.15, -6), (4.5, 5), (4.85, -3), (5.2, 0)] { plan.leaf.add(value, at: time) }
        plan.stretch.hold(until: lowered)
        plan.stretch.add(0.045, at: 4.1)
        plan.stretch.add(0, at: 5.2)
        return plan.closed()
    }

    /// 선글라스 고쳐 쓰기: 팔이 올라와(0.45초) 선글라스를 밀어 올리고(0.35초) 잠깐 있다가 제자리에 얹고 팔을 내린다.
    static func adjust() -> VacationMotionPlan {
        var plan = VacationMotionPlan(duration: 2.4)
        // 팔: 아래에서 올라오며 나타난다.
        plan.armAdjustX = SaessagiTrack(start: 14)
        plan.armAdjustY = SaessagiTrack(start: 40)
        plan.armAdjustOpacity.add(1, at: 0.25)
        plan.armAdjustX.add(0, at: 0.45)
        plan.armAdjustY.add(0, at: 0.45)
        plan.armAdjustY.add(-8, at: 0.8)
        plan.armAdjustY.hold(until: 1.3)
        plan.armAdjustY.add(0, at: 1.7)
        plan.armAdjustX.hold(until: 1.75)
        plan.armAdjustY.hold(until: 1.75)
        plan.armAdjustOpacity.hold(until: 2.0)
        plan.armAdjustX.add(14, at: 2.3)
        plan.armAdjustY.add(40, at: 2.3)
        plan.armAdjustOpacity.add(0, at: 2.3)
        // 선글라스: 손이 닿으면 살짝 들리며 기울고, 놓으면 조금 내려앉았다가 제자리.
        plan.glassesY.hold(until: 0.45)
        plan.glassesTilt.hold(until: 0.45)
        plan.glassesY.add(-9, at: 0.8)
        plan.glassesTilt.add(-4, at: 0.8)
        plan.glassesY.hold(until: 1.3)
        plan.glassesTilt.hold(until: 1.3)
        plan.glassesY.add(2, at: 1.6)
        plan.glassesTilt.add(0.8, at: 1.6)
        plan.glassesY.add(0, at: 1.75)
        plan.glassesTilt.add(0, at: 1.75)
        return plan.closed()
    }

    /// 바람: 잎이 크게 흔들리다 잦아든다.
    static func flutter() -> VacationMotionPlan {
        var plan = VacationMotionPlan(duration: 2.2)
        for (time, value) in [(0.3, 10.0), (0.65, -7), (1.0, 7), (1.35, -4), (1.7, 3), (2.2, 0)] { plan.leaf.add(value, at: time) }
        return plan.closed()
    }

    /// 깊은 숨: 천천히 들이쉬고 길게 내쉰다.
    static func sigh() -> VacationMotionPlan {
        var plan = VacationMotionPlan(duration: 2.8)
        plan.stretch.add(0.05, at: 1.1)
        plan.stretch.add(0, at: 2.8)
        for (time, value) in [(1.1, -5.0), (1.9, 3), (2.8, 0)] { plan.leaf.add(value, at: time) }
        return plan.closed()
    }

    /// 모든 값의 키프레임과 그것을 고쳐 쓰는 길. 줄을 맞추거나 한꺼번에 검사할 때 쓴다.
    static let tracks: [WritableKeyPath<VacationMotionPlan, SaessagiTrack>] = [
        \.drinkX, \.drinkY, \.drinkTilt, \.handRestX, \.handRestY, \.handRestOpacity, \.armSipOpacity,
        \.armAdjustOpacity, \.armAdjustX, \.armAdjustY, \.glassesY, \.glassesTilt, \.leaf, \.stretch,
    ]

    /// 모든 값을 행동이 끝나는 때까지 이어 둔다(키프레임의 시간을 전체 길이에 대한 비율로 쓰기 때문이다).
    private func closed() -> VacationMotionPlan {
        var plan = self
        for track in Self.tracks { plan[keyPath: track].hold(until: duration) }
        return plan
    }
}
