import Foundation

/// 새싹이가 평소 모습에서 가끔 하는 행동. 한 번에 하나만 한다.
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
    /// 넘어졌다 일어나기, 빼꼼 숨기: 새 그림이 있어야 해서 아직 만들지 않았다.
    case tumble
    case peek

    /// 고를 때의 비중. 0이면 고르지 않는다. 쉬는 것이 가장 흔하다.
    var weight: Int {
        switch self {
        case .stay: return 8
        case .walk: return 6
        case .lookAround: return 6
        case .hop: return 4
        case .doze: return 3
        case .tumble, .peek: return 0
        }
    }

    var isAvailable: Bool { weight > 0 }

    /// 다음 행동을 비중대로 고른다. 바로 앞에 한 행동은 다시 고르지 않는다.
    static func next(after last: SaessagiAction?, using generator: inout some RandomNumberGenerator) -> SaessagiAction {
        let choices = allCases.filter { $0.isAvailable && $0 != last }
        let total = choices.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return .stay }
        var pick = Int.random(in: 0..<total, using: &generator)
        for choice in choices {
            if pick < choice.weight { return choice }
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
    /// 행동 사이에 쉬는 시간(초), 처음 나타났을 때 첫 행동까지의 시간.
    static let rest = 5.0...10.0
    static let firstRest = 3.5
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
