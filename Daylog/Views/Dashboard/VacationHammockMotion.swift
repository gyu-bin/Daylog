import Foundation

/// 해먹 위의 새싹이가 가끔 하는 행동. 늘 도는 움직임(해먹의 흔들림, 숨쉬기, 잎의 살랑임)과 따로, 한 번에 하나만 한다.
enum VacationAction: CaseIterable, Sendable {
    /// 음료를 입가로 가져가 마시고, 내려놓은 뒤 만족스럽게 한숨 돌린다.
    case sip
    /// 선글라스를 살짝 고쳐 쓴다.
    case adjust
    /// 바람이 지나가 잎이 크게 살랑인다.
    case flutter
    /// 깊게 숨을 쉰다(해먹이 조금 더 내려앉았다 돌아온다).
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

/// 행동 한 번의 전체 움직임. 기울기는 도(시계 방향이 양수), 불투명도와 늘어남은 비율이다.
///
/// 마시기와 선글라스 고쳐 쓰기는 받은 그림의 손 언저리(`VacationArt.sipHands`, `adjustHands`)를 해먹 위에 서서히 겹쳐 보여 준다.
/// 그 조각은 같은 해먹 묶음 안에 있어서 해먹이 흔들리는 중에도 어긋나지 않는다. 행동이 끝나면 모든 값이 쉬는 자세로 돌아온다.
struct VacationMotionPlan: Equatable, Sendable {
    var duration: Double
    var sipOpacity = SaessagiTrack()
    var adjustOpacity = SaessagiTrack()
    /// 늘 도는 잎의 살랑임 위에 더하는 기울기.
    var leaf = SaessagiTrack()
    /// 늘 도는 숨쉬기(해먹이 살짝 늘어졌다 오르는 움직임) 위에 더하는 값(1에 더한다).
    var stretch = SaessagiTrack()

    static func make(_ action: VacationAction) -> VacationMotionPlan {
        switch action {
        case .sip: return sip()
        case .adjust: return adjust()
        case .flutter: return flutter()
        case .sigh: return sigh()
        }
    }

    /// 쉬는 그림과 손 그림이 서로 바뀌는 데 걸리는 시간(초).
    static let swap = 0.25

    /// 마시기: 음료를 입가로 가져가 한동안 마시고(2.2초), 내려놓은 뒤 만족스럽게 한숨 돌린다.
    static func sip() -> VacationMotionPlan {
        var plan = VacationMotionPlan(duration: 4.8)
        let raised = 0.2, lowered = 2.6
        plan.sipOpacity.hold(until: raised)
        plan.sipOpacity.add(1, at: raised + swap)
        plan.sipOpacity.hold(until: lowered)
        plan.sipOpacity.add(0, at: lowered + swap)
        // 모금마다 잎이 살짝 들리고, 다 마신 뒤에는 기분 좋게 흔든다.
        for (time, value) in [(0.8, 0.0), (1.05, -4), (1.4, 0), (1.75, -4), (2.1, 0)] { plan.leaf.add(value, at: time) }
        for (time, value) in [(3.1, 0.0), (3.4, 6), (3.75, -4.5), (4.1, 3.5), (4.45, -2), (4.8, 0)] { plan.leaf.add(value, at: time) }
        plan.stretch.hold(until: lowered + swap)
        plan.stretch.add(0.018, at: 3.6)
        plan.stretch.add(0, at: 4.8)
        return plan.closed()
    }

    /// 선글라스 고쳐 쓰기: 손을 올려 선글라스를 매만지고(1.5초) 내린다.
    static func adjust() -> VacationMotionPlan {
        var plan = VacationMotionPlan(duration: 2.5)
        plan.adjustOpacity.hold(until: 0.15)
        plan.adjustOpacity.add(1, at: 0.15 + swap)
        plan.adjustOpacity.hold(until: 1.9)
        plan.adjustOpacity.add(0, at: 1.9 + swap)
        for (time, value) in [(0.4, 0.0), (0.7, 3), (1.0, -2), (1.3, 0)] { plan.leaf.add(value, at: time) }
        return plan.closed()
    }

    /// 바람: 잎이 크게 흔들리다 잦아든다.
    static func flutter() -> VacationMotionPlan {
        var plan = VacationMotionPlan(duration: 2.2)
        for (time, value) in [(0.3, 7.0), (0.65, -5), (1.0, 5), (1.35, -3), (1.7, 2), (2.2, 0)] { plan.leaf.add(value, at: time) }
        return plan.closed()
    }

    /// 깊은 숨: 해먹이 천천히 조금 더 내려앉았다가 돌아온다.
    static func sigh() -> VacationMotionPlan {
        var plan = VacationMotionPlan(duration: 2.8)
        plan.stretch.add(0.022, at: 1.1)
        plan.stretch.add(0, at: 2.8)
        for (time, value) in [(1.1, -3.5), (1.9, 2), (2.8, 0)] { plan.leaf.add(value, at: time) }
        return plan.closed()
    }

    /// 모든 값의 키프레임과 그것을 고쳐 쓰는 길. 줄을 맞추거나 한꺼번에 검사할 때 쓴다.
    static let tracks: [WritableKeyPath<VacationMotionPlan, SaessagiTrack>] = [\.sipOpacity, \.adjustOpacity, \.leaf, \.stretch]

    /// 모든 값을 행동이 끝나는 때까지 이어 둔다(키프레임의 시간을 전체 길이에 대한 비율로 쓰기 때문이다).
    private func closed() -> VacationMotionPlan {
        var plan = self
        for track in Self.tracks { plan[keyPath: track].hold(until: duration) }
        return plan
    }
}
