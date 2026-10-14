import Foundation

/// 새싹이가 가끔 하는 행동. 한 번에 하나만 한다. 어떤 행동을 얼마나 자주 하는지는 놓인 자리마다 `SaessagiBehavior`가 정한다.
///
/// 앞의 다섯은 몸·발·눈·입·잎이 나뉜 기본 모습에서 하고, 그다음 여섯은 그림 한 장짜리 모습(응원·반가움·기쁨·휴식·잠)에서도 한다:
/// 팔다리를 따로 움직이지 않고 그림 전체를 발밑 기준으로 기울이고, 띄우고, 눌렀다 늘린다.
enum SaessagiAction: CaseIterable, Sendable {
    /// 아무것도 하지 않고 더 쉰다(숨 쉬고 깜빡이기만 한다).
    case stay
    /// 종종걸음으로 옆으로 몇 걸음 옮겨 간다.
    case walk
    /// 왼쪽을 봤다가 오른쪽을 본다.
    case lookAround
    /// 제자리에서 폴짝 뛴다.
    case hop
    /// 꾸벅꾸벅 졸다가 놀라 깬다.
    case doze
    /// 좌우로 몸을 흔든다.
    case sway
    /// 작게 통 뛴다.
    case bounce
    /// 좌우로 기울며 두 번 크게 뛴다(축하).
    case cheer
    /// 든 손 쪽으로 몸을 까딱까딱 기울인다(손을 따로 움직일 수 없어 몸으로 흔든다).
    case wave
    /// 느리게 꿈틀한다.
    case wiggle
    /// 크게 한 번 숨을 쉰다.
    case deepBreath
    /// 넘어졌다 일어나기, 빼꼼 숨기: 새 그림이 있어야 해서 아직 만들지 않았다.
    case tumble
    case peek

    var isAvailable: Bool { self != .tumble && self != .peek }
    /// 나뉜 레이어(발·눈·입·잎)가 있어야 하는 행동.
    var needsLayers: Bool { self == .walk || self == .lookAround || self == .doze }
}

/// 새싹이가 놓인 자리에서 어떻게 움직일지: 고를 행동과 비중, 쉬는 시간, 숨의 크기.
struct SaessagiBehavior: Equatable, Sendable {
    struct Choice: Equatable, Sendable {
        var action: SaessagiAction
        var weight: Int
    }

    var choices: [Choice]
    /// 행동 사이에 쉬는 시간(초)과, 처음 나타났을 때 첫 행동까지의 시간.
    var rest: ClosedRange<Double>
    var firstRest: Double
    /// 숨을 들이쉴 때 키가 늘어나는 비율과, 들숨 또는 날숨 한 번의 시간(초).
    var breathStretch = SaessagiIdleMotion.breathStretch
    var breathHalfPeriod = SaessagiIdleMotion.breathHalfPeriod

    private static func make(
        _ choices: [(SaessagiAction, Int)], rest: ClosedRange<Double>, firstRest: Double,
        breathStretch: Double = SaessagiIdleMotion.breathStretch, breathHalfPeriod: Double = SaessagiIdleMotion.breathHalfPeriod
    ) -> SaessagiBehavior {
        SaessagiBehavior(
            choices: choices.map { Choice(action: $0.0, weight: $0.1) }, rest: rest, firstRest: firstRest,
            breathStretch: breathStretch, breathHalfPeriod: breathHalfPeriod
        )
    }

    /// 오늘 화면 인사말 옆: 걷고, 두리번거리고, 뛰고, 존다.
    static let today = make([(.stay, 3), (.walk, 6), (.lookAround, 6), (.hop, 4), (.doze, 3)], rest: 2...5, firstRest: 2)
    /// 기다리는 안내 화면: 주로 두리번거린다.
    static let waiting = make([(.lookAround, 6), (.hop, 2), (.stay, 2)], rest: 2...4, firstRest: 1.2)
    /// 가만히: 숨 쉬고 깜빡이기만 한다.
    static let calm = make([], rest: 4...8, firstRest: 4)
    /// 작은 카드의 응원: 좌우로 흔들고 가볍게 뛴다.
    static let cheering = make([(.sway, 5), (.bounce, 4)], rest: 1.5...3.5, firstRest: 1.5)
    /// 목표를 달성했을 때: 더 자주, 더 크게.
    static let celebrating = make([(.cheer, 5), (.sway, 3), (.bounce, 3)], rest: 1.2...3, firstRest: 0.8)
    /// 반기는 인사: 손을 흔들듯 까딱이고 가끔 뛴다.
    static let welcoming = make([(.wave, 6), (.bounce, 3)], rest: 1.5...3.5, firstRest: 1)
    /// 기뻐하는 잠깐의 반응: 곧바로 통통 뛴다.
    static let joyful = make([(.bounce, 1)], rest: 0.25...0.5, firstRest: 0.45)
    /// 쉬는 모습: 느리게 숨 쉬고 가끔 꿈틀한다.
    static let resting = make(
        [(.wiggle, 4), (.stay, 1)], rest: 2.5...5, firstRest: 1.5, breathStretch: 0.05, breathHalfPeriod: 2.0
    )
    /// 자는 모습: 더 느린 숨, 가끔 크게 한 번.
    static let sleeping = make(
        [(.deepBreath, 4), (.wiggle, 1), (.stay, 2)], rest: 3...6, firstRest: 2.5, breathStretch: 0.045, breathHalfPeriod: 2.6
    )

    /// 새싹이 성장 카드: 숨 쉬고 깜빡이며 잎을 흔들다가, 가끔 좌우로 몸을 흔들거나 폴짝 뛴다.
    /// (성장 단계 그림은 발과 입이 몸에 붙어 있어 걷기·두리번거리기는 하지 않는다.)
    static let growing = make([(.sway, 4), (.hop, 3), (.stay, 2)], rest: 2...4.5, firstRest: 1.6)

    /// 그 모습에 어울리는 기본 움직임.
    static func standard(for pose: SaessagiPose) -> SaessagiBehavior {
        switch pose {
        case .idle: return .waiting
        case .happy: return .joyful
        case .cheer: return .cheering
        case .rest: return .resting
        case .sleep: return .sleeping
        case .welcome: return .welcoming
        case .growthSprout, .growthLeaf, .growthFlower: return .growing
        }
    }

    /// 다음 행동을 비중대로 고른다. 바로 앞에 한 행동은 다시 고르지 않는다(고를 것이 그것뿐이면 다시 한다).
    func next(after last: SaessagiAction?, using generator: inout some RandomNumberGenerator) -> SaessagiAction {
        let usable = choices.filter { $0.action.isAvailable && $0.weight > 0 }
        let fresh = usable.filter { $0.action != last }
        let pool = fresh.isEmpty ? usable : fresh
        let total = pool.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return .stay }
        var pick = Int.random(in: 0..<total, using: &generator)
        for choice in pool {
            if pick < choice.weight { return choice.action }
            pick -= choice.weight
        }
        return .stay
    }
}

/// 행동들의 크기와 박자. 길이는 새싹이의 키(`size`)에 대한 비율이다.
enum SaessagiWalkMotion {
    /// 한 걸음의 시간(초): 1초에 서너 걸음.
    static let stepDuration = 0.28
    /// 한 걸음에 나아가는 거리.
    static let stepLength = 0.07
    /// 발을 드는 높이.
    static let footLift = 0.05
    /// 걸음마다 몸이 통통 뜨는 높이.
    static let bob = 0.03
    /// 디딘 발 쪽으로 몸이 기우는 각도(도)와, 가는 쪽으로 숙이는 각도.
    static let rock = 4.0
    static let lean = 2.5
    /// 잎이 걸음에 맞춰 흔들리는 각도와, 뒤로 처지는 각도.
    static let leafSwing = 8.0
    static let leafTrail = 5.0
    /// 가는 쪽을 보느라 눈과 입이 옮겨 가는 거리.
    static let faceShift = 0.034
    /// 걷기 전에 가는 쪽을 보는 시간, 다 걷고 앞을 보는 시간(초).
    static let faceTurn = 0.2
    /// 한 번에 걷는 걸음 수: 이보다 적게 걸을 자리밖에 없으면 걷지 않고, 이보다 많이 걷지 않는다(2~3초).
    static let minimumSteps = 4
    static let maximumSteps = 9
}

/// 시간에 따라 변하는 값 하나(키프레임). 시간은 초, 처음은 0초.
struct SaessagiTrack: Equatable, Sendable {
    private(set) var times: [Double] = [0]
    private(set) var values: [Double]

    init(start: Double = 0) {
        values = [start]
    }

    var last: Double { values[values.count - 1] }
    var end: Double { times[times.count - 1] }
    /// 처음부터 끝까지 같은 값이다(움직임이 없다).
    var isConstant: Bool { values.allSatisfy { $0 == values[0] } }

    mutating func add(_ value: Double, at time: Double) {
        if time <= end + 1e-9 {
            values[values.count - 1] = value
        } else {
            times.append(time)
            values.append(value)
        }
    }

    mutating func hold(until time: Double) {
        if time > end + 1e-9 { add(last, at: time) }
    }

    /// 그 시각의 값(키프레임 사이는 곧게 잇는다).
    func value(at time: Double) -> Double {
        guard time > 0 else { return values[0] }
        for index in 1..<times.count where time <= times[index] {
            let span = times[index] - times[index - 1]
            let progress = span > 0 ? (time - times[index - 1]) / span : 1
            return values[index - 1] + (values[index] - values[index - 1]) * progress
        }
        return last
    }
}

/// 행동 한 번의 전체 움직임. 값의 단위는 pt와 도이고, 오른쪽과 위가 양수다.
///
/// 걷기에서 발은 몸에 대한 상대 위치로 적는다. 디딘 발은 몸이 나아간 만큼 뒤로 가서 땅에서는 제자리에 있고(미끄러지지 않는다),
/// 든 발은 그동안 앞으로 나간다. 첫 걸음과 마지막 걸음은 반 걸음이라 모았던 발에서 천천히 출발해 모은 발로 천천히 멈춘다.
struct SaessagiMotionPlan: Equatable, Sendable {
    private(set) var duration = 0.0
    /// 걷기의 걸음 수(다른 행동은 0).
    private(set) var steps = 0
    /// 제자리(왼쪽 끝)에서 오른쪽으로 떨어진 거리.
    private(set) var moverX: SaessagiTrack
    /// 몸 전체가 뜬 높이.
    private(set) var bob = SaessagiTrack()
    /// 발밑을 기준으로 한 가로·세로 배율(눌림과 늘어남).
    private(set) var squashX = SaessagiTrack(start: 1)
    private(set) var squashY = SaessagiTrack(start: 1)
    private(set) var footLeftX = SaessagiTrack()
    private(set) var footLeftLift = SaessagiTrack()
    private(set) var footRightX = SaessagiTrack()
    private(set) var footRightLift = SaessagiTrack()
    /// 몸이 기우는 각도(오른쪽으로 기울면 양수).
    private(set) var rock = SaessagiTrack()
    /// 잎이 더 기우는 각도.
    private(set) var leaf = SaessagiTrack()
    /// 눈과 입이 옮겨 간 거리.
    private(set) var face = SaessagiTrack()
    /// 눈의 세로 배율(1 = 뜬 눈). 깜빡임 대신 이 값이 쓰인다.
    private(set) var eyes = SaessagiTrack(start: 1)

    private init(startX: Double) {
        moverX = SaessagiTrack(start: startX)
    }

    /// 그 시각에 제자리에서 얼마나 떨어져 있는가.
    func position(at time: Double) -> Double {
        moverX.value(at: time)
    }

    /// 행동이 끝났을 때 서 있는 자리.
    var finalX: Double { moverX.last }

    // MARK: - 걷기

    /// 지금 자리(`x`)에서 걸어갈 곳을 고른다: 자리(0…`range`) 안에서 몇 걸음 떨어진 곳. 걸을 자리가 없으면 nil.
    static func walkTarget(
        from x: Double, range: Double, size: Double, using generator: inout some RandomNumberGenerator
    ) -> Double? {
        let step = SaessagiWalkMotion.stepLength * size
        guard step > 0 else { return nil }
        let shortest = Double(SaessagiWalkMotion.minimumSteps - 1) * step
        let longest = Double(SaessagiWalkMotion.maximumSteps - 1) * step
        let left = min(max(x, 0), longest), right = min(max(range - x, 0), longest)
        var options: [(direction: Double, room: Double)] = []
        if left >= shortest { options.append((-1, left)) }
        if right >= shortest { options.append((1, right)) }
        // 자리가 더 넓은 쪽으로 더 자주 간다.
        let total = options.reduce(0) { $0 + $1.room }
        guard total > 0 else { return nil }
        var pick = Double.random(in: 0..<total, using: &generator)
        for option in options {
            if pick < option.room {
                let distance = Double.random(in: shortest...option.room, using: &generator)
                return min(max(x + option.direction * distance, 0), range)
            }
            pick -= option.room
        }
        return nil
    }

    /// `x`에서 `target`까지 걷는다. 가는 쪽을 먼저 보고, 걷고, 멈춰서 앞을 본다.
    static func walk(from x: Double, to target: Double, size: Double) -> SaessagiMotionPlan? {
        let nominal = SaessagiWalkMotion.stepLength * size
        let distance = abs(target - x)
        guard nominal > 0, distance > 0.5 else { return nil }
        let steps = min(max(2, Int((distance / nominal).rounded()) + 1), SaessagiWalkMotion.maximumSteps)
        var plan = SaessagiMotionPlan(startX: x)
        plan.steps = steps
        let direction = target > x ? 1.0 : -1.0
        // 가는 쪽을 본 다음에 발을 뗀다.
        plan.face.add(direction * SaessagiWalkMotion.faceShift * size, at: SaessagiWalkMotion.faceTurn)
        plan.duration = SaessagiWalkMotion.faceTurn * 0.6
        plan.stride(steps: steps, stepLength: distance / Double(steps - 1), direction: direction, size: size)
        plan.face.hold(until: plan.duration)
        plan.face.add(0, at: plan.duration + SaessagiWalkMotion.faceTurn)
        plan.duration += SaessagiWalkMotion.faceTurn
        plan.holdAll(until: plan.duration)
        return plan
    }

    private mutating func stride(steps: Int, stepLength: Double, direction: Double, size: Double) {
        let period = SaessagiWalkMotion.stepDuration
        let start = duration
        let half = stepLength / 2
        var x = moverX.last
        holdAll(until: start, except: \.face)
        for index in 0..<steps {
            let middle = start + (Double(index) + 0.5) * period
            let finish = start + Double(index + 1) * period
            let isLast = index == steps - 1
            // 가는 쪽의 발부터 내딛는다.
            let swingsRight = (direction > 0) == (index % 2 == 0)
            x += direction * (index == 0 || isLast ? half : stepLength)
            moverX.add(x, at: finish)
            let swingEnd = isLast ? 0 : direction * half
            let stanceEnd = isLast ? 0 : -direction * half
            let lift = SaessagiWalkMotion.footLift * size
            if swingsRight {
                footRightX.add(swingEnd, at: finish)
                footRightLift.add(lift, at: middle)
                footRightLift.add(0, at: finish)
                footLeftX.add(stanceEnd, at: finish)
                footLeftLift.add(0, at: finish)
            } else {
                footLeftX.add(swingEnd, at: finish)
                footLeftLift.add(lift, at: middle)
                footLeftLift.add(0, at: finish)
                footRightX.add(stanceEnd, at: finish)
                footRightLift.add(0, at: finish)
            }
            bob.add(SaessagiWalkMotion.bob * size, at: middle)
            bob.add(0, at: finish)
            // 디딘 발 쪽으로 기운다: 오른발을 들면 왼쪽으로. 잎은 반대로 늦게 따라온다.
            let side = swingsRight ? -1.0 : 1.0
            rock.add(direction * SaessagiWalkMotion.lean + side * SaessagiWalkMotion.rock, at: middle)
            leaf.add(-direction * SaessagiWalkMotion.leafTrail - side * SaessagiWalkMotion.leafSwing, at: middle)
        }
        duration = start + Double(steps) * period
        rock.add(0, at: duration)
        // 멈춘 뒤 잎이 한 번 앞으로 넘어갔다 돌아온다.
        leaf.add(direction * SaessagiWalkMotion.leafTrail * 0.6, at: duration)
        leaf.add(0, at: duration + SaessagiWalkMotion.faceTurn)
    }

    // MARK: - 두리번거리기

    /// 제자리에서 왼쪽을 봤다가 오른쪽을 본다. 몸도 보는 쪽으로 조금 기운다.
    static func lookAround(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        let look = SaessagiWalkMotion.faceShift * size * 1.25
        let tilt = 3.0
        // (시각, 보는 쪽): 왼쪽을 보고 머물렀다가, 오른쪽을 보고 머물렀다가, 앞으로.
        let poses: [(time: Double, side: Double)] = [(0.26, -1), (0.66, -1), (0.98, 1), (1.42, 1), (1.7, 0)]
        for pose in poses {
            plan.face.add(pose.side * look, at: pose.time)
            plan.rock.add(pose.side * tilt, at: pose.time)
        }
        // 잎은 고개를 돌릴 때 반대로 처졌다가 따라온다.
        let leaf: [(Double, Double)] = [(0.2, 5), (0.5, -2), (0.66, 0), (0.9, -6), (1.2, 2), (1.42, 0), (1.62, 3), (1.85, 0)]
        for (time, angle) in leaf { plan.leaf.add(angle, at: time) }
        plan.duration = 1.85
        plan.holdAll(until: plan.duration)
        return plan
    }

    // MARK: - 폴짝 뛰기

    /// 제자리에서 작게 뛴다: 움츠렸다가 뛰어오르고, 내려앉으며 눌렸다가 돌아온다. 잎은 한 박자 늦게 흔들린다.
    static func hop(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        let height = 0.2 * size
        // 움츠림 → 도약 → 꼭대기 → 착지.
        let bob: [(Double, Double)] = [(0.14, 0), (0.24, 0.62), (0.36, 1), (0.47, 0.66), (0.56, 0)]
        for (time, level) in bob { plan.bob.add(level * height, at: time) }
        let squash: [(time: Double, x: Double, y: Double)] = [
            (0.14, 1.07, 0.9), (0.24, 0.96, 1.07), (0.36, 1, 1), (0.54, 0.98, 1.03),
            (0.64, 1.09, 0.88), (0.78, 0.98, 1.03), (0.92, 1, 1),
        ]
        for pose in squash {
            plan.squashX.add(pose.x, at: pose.time)
            plan.squashY.add(pose.y, at: pose.time)
        }
        // 떠 있는 동안 두 발을 살짝 든다.
        let tuck = 0.035 * size
        for (time, level) in [(0.16, 0.0), (0.36, 1.0), (0.56, 0.0)] {
            plan.footLeftLift.add(level * tuck, at: time)
            plan.footRightLift.add(level * tuck, at: time)
        }
        // 잎: 뛰어오를 때 뒤로 눕고, 내려앉은 뒤에 크게 흔들리다 잦아든다.
        let leaf: [(Double, Double)] = [(0.14, 2), (0.26, -7), (0.44, 3), (0.66, 13), (0.82, -8), (0.96, 4), (1.1, 0)]
        for (time, angle) in leaf { plan.leaf.add(angle, at: time) }
        plan.duration = 1.1
        plan.holdAll(until: plan.duration)
        return plan
    }

    // MARK: - 꾸벅꾸벅 졸기

    /// 눈을 감고 고개가 두 번 기울다가, 놀라서 깨어 눈을 크게 뜨고 돌아온다.
    static func doze(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        let closed = SaessagiIdleMotion.closedEyeScale
        // 눈: 천천히 감고, 졸다가, 번쩍 뜬 뒤 평소 크기로.
        for (time, scale) in [(0.2, 1.0), (0.6, closed), (2.05, closed), (2.14, 1.16), (2.4, 1.16), (2.65, 1.0)] {
            plan.eyes.add(scale, at: time)
        }
        // 고개: 꾸벅(조금) → 살짝 들었다가 → 꾸벅(많이) → 번쩍.
        for (time, angle) in [(0.3, 0.0), (0.8, 5.0), (1.1, 3.0), (1.7, 9.5), (2.05, 9.5), (2.16, -2.5), (2.4, -1.0), (2.7, 0.0)] {
            plan.rock.add(angle, at: time)
        }
        // 몸이 조금 가라앉았다가 놀라며 늘어난다.
        for (time, scale) in [(0.3, 1.0), (0.8, 0.975), (1.1, 0.985), (1.7, 0.955), (2.05, 0.955), (2.16, 1.045), (2.4, 0.99), (2.6, 1.0)] {
            plan.squashY.add(scale, at: time)
        }
        // 놀라서 살짝 뜬다.
        for (time, level) in [(2.05, 0.0), (2.16, 0.07 * size), (2.3, 0.0)] { plan.bob.add(level, at: time) }
        // 잎은 고개를 따라 늦게 처지고, 깰 때 반대로 튄다.
        for (time, angle) in [(0.4, 0.0), (0.95, 4.0), (1.2, 2.0), (1.85, 9.0), (2.05, 9.0), (2.2, -9.0), (2.42, 5.0), (2.62, -2.0), (2.8, 0.0)] {
            plan.leaf.add(angle, at: time)
        }
        plan.duration = 2.8
        plan.holdAll(until: plan.duration)
        return plan
    }

    // MARK: - 그림 한 장으로도 하는 행동

    /// 좌우로 몸을 흔든다.
    static func sway(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        for (time, angle) in [(0.24, -6.0), (0.56, 6.0), (0.88, -4.0), (1.15, 2.0), (1.35, 0.0)] { plan.rock.add(angle, at: time) }
        for (time, level) in [(0.24, 0.03), (0.4, 0.0), (0.56, 0.03), (0.72, 0.0), (0.88, 0.02), (1.05, 0.0)] {
            plan.bob.add(level * size, at: time)
        }
        plan.duration = 1.35
        plan.holdAll(until: plan.duration)
        return plan
    }

    /// 작게 통 뛴다. 작은 카드 안에서도 자리를 벗어나지 않는 높이다.
    static func bounce(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        plan.jump(from: 0, height: 0.1 * size, tilt: 0)
        plan.duration = 0.8
        plan.holdAll(until: plan.duration)
        return plan
    }

    /// 좌우로 기울며 두 번 뛴다(축하).
    static func cheer(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        plan.jump(from: 0, height: 0.15 * size, tilt: -5)
        plan.jump(from: 0.66, height: 0.15 * size, tilt: 5)
        plan.rock.add(0, at: 1.5)
        plan.duration = 1.55
        plan.holdAll(until: plan.duration)
        return plan
    }

    /// 든 손 쪽(오른쪽)으로 몸을 까딱까딱 기울인다.
    static func wave(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        for (time, angle) in [(0.18, 7.0), (0.36, 2.0), (0.54, 7.0), (0.72, 2.0), (0.9, 6.0), (1.2, 0.0)] {
            plan.rock.add(angle, at: time)
        }
        for (time, level) in [(0.18, 0.025), (0.36, 0.0), (0.54, 0.025), (0.72, 0.0), (0.9, 0.02), (1.1, 0.0)] {
            plan.bob.add(level * size, at: time)
        }
        plan.duration = 1.2
        plan.holdAll(until: plan.duration)
        return plan
    }

    /// 느리게 꿈틀한다: 살짝 퍼졌다가 늘어나며 좌우로 조금 기운다.
    static func wiggle(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        let poses: [(time: Double, x: Double, y: Double, tilt: Double)] = [
            (0.45, 1.055, 0.95, -3), (0.9, 0.975, 1.035, 2.5), (1.35, 1.04, 0.965, -1.5), (1.8, 1, 1, 0),
        ]
        for pose in poses {
            plan.squashX.add(pose.x, at: pose.time)
            plan.squashY.add(pose.y, at: pose.time)
            plan.rock.add(pose.tilt, at: pose.time)
        }
        plan.duration = 1.8
        plan.holdAll(until: plan.duration)
        return plan
    }

    /// 크게 한 번 숨을 쉰다.
    static func deepBreath(at x: Double, size: Double) -> SaessagiMotionPlan {
        var plan = SaessagiMotionPlan(startX: x)
        for (time, wide, tall) in [(1.3, 0.985, 1.055), (1.7, 0.985, 1.055), (3.0, 1.0, 1.0)] {
            plan.squashX.add(wide, at: time)
            plan.squashY.add(tall, at: time)
        }
        plan.duration = 3.0
        plan.holdAll(until: plan.duration)
        return plan
    }

    /// 뛰기 한 번을 `start`초부터 더한다: 움츠림 → 도약 → 착지 → 눌렸다 복원(약 0.75초). `tilt`만큼 기운 채 뛴다.
    private mutating func jump(from start: Double, height: Double, tilt: Double) {
        bob.hold(until: start + 0.1)
        for (time, level) in [(0.18, 0.62), (0.28, 1.0), (0.37, 0.66), (0.45, 0.0)] { bob.add(level * height, at: start + time) }
        squashX.hold(until: start)
        squashY.hold(until: start)
        let squash: [(Double, Double, Double)] = [
            (0.1, 1.05, 0.93), (0.18, 0.97, 1.05), (0.28, 1, 1), (0.44, 0.985, 1.02), (0.52, 1.07, 0.91), (0.64, 0.985, 1.02), (0.75, 1, 1),
        ]
        for (time, wide, tall) in squash {
            squashX.add(wide, at: start + time)
            squashY.add(tall, at: start + time)
        }
        if tilt != 0 {
            rock.hold(until: start)
            rock.add(tilt, at: start + 0.2)
            rock.add(tilt * 0.4, at: start + 0.55)
        }
    }

    // MARK: - 고르기

    /// 그 행동의 움직임을 만든다. 하지 않는 행동(쉬기, 아직 없는 동작)이나 할 수 없는 경우(걸을 자리 없음)는 nil.
    static func make(
        _ action: SaessagiAction, at x: Double, range: Double, size: Double, using generator: inout some RandomNumberGenerator
    ) -> SaessagiMotionPlan? {
        switch action {
        case .stay, .tumble, .peek:
            return nil
        case .walk:
            return walkTarget(from: x, range: range, size: size, using: &generator).flatMap { walk(from: x, to: $0, size: size) }
        case .lookAround: return lookAround(at: x, size: size)
        case .hop: return hop(at: x, size: size)
        case .doze: return doze(at: x, size: size)
        case .sway: return sway(at: x, size: size)
        case .bounce: return bounce(at: x, size: size)
        case .cheer: return cheer(at: x, size: size)
        case .wave: return wave(at: x, size: size)
        case .wiggle: return wiggle(at: x, size: size)
        case .deepBreath: return deepBreath(at: x, size: size)
        }
    }

    // MARK: -

    private mutating func holdAll(until time: Double, except skipped: PartialKeyPath<SaessagiMotionPlan>? = nil) {
        let tracks: [WritableKeyPath<SaessagiMotionPlan, SaessagiTrack>] = [
            \.moverX, \.bob, \.squashX, \.squashY, \.footLeftX, \.footLeftLift, \.footRightX, \.footRightLift,
            \.rock, \.leaf, \.face, \.eyes,
        ]
        for track in tracks where track != skipped {
            self[keyPath: track].hold(until: time)
        }
    }
}
