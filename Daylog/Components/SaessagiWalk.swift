import Foundation

/// 새싹이가 평소 모습에서 가끔 하는 행동. 지금은 걷기만 있다. 나머지는 자리만 잡아 둔 것이다:
/// 동작을 만들면 `isAvailable`을 켜고 `SaessagiIdleStage.play(_:)`에 그 동작의 애니메이션을 더한다.
enum SaessagiAction: CaseIterable, Sendable {
    /// 종종걸음으로 옆으로 갔다가 돌아온다.
    case walk
    /// 두리번거리기.
    case lookAround
    /// 폴짝 뛰기.
    case hop
    /// 넘어졌다 일어나기.
    case tumble
    /// 빼꼼 숨기.
    case peek
    /// 꾸벅꾸벅 졸기.
    case doze

    var isAvailable: Bool { self == .walk }

    static func next(using generator: inout some RandomNumberGenerator) -> SaessagiAction {
        allCases.filter(\.isAvailable).randomElement(using: &generator) ?? .walk
    }
}

/// 종종걸음의 크기와 박자. 길이는 새싹이의 키(`size`)에 대한 비율이다.
enum SaessagiWalkMotion {
    /// 한 걸음의 시간(초). 짧고 잦은 걸음.
    static let stepDuration = 0.14
    /// 한 걸음에 나아가는 거리.
    static let stepLength = 0.055
    /// 발을 드는 높이.
    static let footLift = 0.05
    /// 걸음마다 몸이 통통 뜨는 높이.
    static let bob = 0.03
    /// 디딘 발 쪽으로 몸이 기우는 각도(도)와, 가는 쪽으로 숙이는 각도.
    static let rock = 5.0
    static let lean = 3.0
    /// 잎이 걸음에 맞춰 흔들리는 각도와, 뒤로 처지는 각도.
    static let leafSwing = 9.0
    static let leafTrail = 6.0
    /// 가는 쪽을 보느라 눈과 입이 옮겨 가는 거리.
    static let faceShift = 0.034
    /// 끝에서 돌아서는 시간과, 얼굴을 돌리는 시간(초).
    static let turnPause = 0.5
    static let faceTurn = 0.18
    /// 이보다 적게 걸을 자리밖에 없으면 걷지 않는다.
    static let minimumSteps = 3
    /// 한쪽으로 걷는 걸음 수의 상한.
    static let maximumSteps = 22
    /// 걷고 난 뒤 다음 행동까지 쉬는 시간(초), 처음 나타났을 때 첫 행동까지의 시간.
    static let rest = 7.0...12.0
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

/// 걷기 한 번의 전체 움직임. 값의 단위는 pt와 도이고, 오른쪽과 위가 양수다.
///
/// 발은 몸에 대한 상대 위치로 적는다. 디딘 발은 몸이 나아간 만큼 뒤로 가서 땅에서는 제자리에 있고(미끄러지지 않는다),
/// 든 발은 그동안 앞으로 나간다. 첫 걸음과 마지막 걸음은 반 걸음이라 모았던 발에서 시작해 모은 발로 끝난다.
struct SaessagiWalkPlan: Equatable, Sendable {
    private(set) var duration = 0.0
    /// 한쪽으로 걷는 걸음 수(가는 길 기준).
    private(set) var stepsPerLeg = 0
    private(set) var moverX: SaessagiTrack
    private(set) var bob = SaessagiTrack()
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

    private init(startX: Double) {
        moverX = SaessagiTrack(start: startX)
    }

    /// 제자리(0)에서 오른쪽 끝까지 갔다가 돌아온다. 걸을 자리가 모자라면 nil.
    static func roundTrip(range: Double, size: Double) -> SaessagiWalkPlan? {
        let step = SaessagiWalkMotion.stepLength * size
        guard step > 0 else { return nil }
        let steps = min(SaessagiWalkMotion.maximumSteps, Int(range / step) + 1)
        guard steps >= SaessagiWalkMotion.minimumSteps else { return nil }
        var plan = SaessagiWalkPlan(startX: 0)
        plan.stepsPerLeg = steps
        plan.walk(steps: steps, stepLength: step, direction: 1, size: size)
        plan.turn(to: -1, size: size)
        plan.walk(steps: steps, stepLength: step, direction: -1, size: size)
        plan.settle()
        return plan
    }

    /// 떨어져 있던 자리(`x`)에서 제자리로 걸어 돌아온다.
    static func returnHome(from x: Double, size: Double) -> SaessagiWalkPlan? {
        let nominal = SaessagiWalkMotion.stepLength * size
        guard x > 0.5, nominal > 0 else { return nil }
        let steps = max(2, Int((x / nominal).rounded()) + 1)
        var plan = SaessagiWalkPlan(startX: x)
        plan.stepsPerLeg = steps
        plan.walk(steps: steps, stepLength: x / Double(steps - 1), direction: -1, size: size)
        plan.settle()
        return plan
    }

    /// 그 시각에 제자리에서 얼마나 떨어져 있는가.
    func position(at time: Double) -> Double {
        moverX.value(at: time)
    }

    private mutating func walk(steps: Int, stepLength: Double, direction: Double, size: Double) {
        let period = SaessagiWalkMotion.stepDuration
        let start = duration
        let half = stepLength / 2
        var x = moverX.last
        holdAll(until: start)
        // 가는 쪽을 본다.
        let look = direction * SaessagiWalkMotion.faceShift * size
        if abs(face.last - look) > 1e-9 { face.add(look, at: start + SaessagiWalkMotion.faceTurn) }
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
        leaf.add(0, at: duration)
        holdAll(until: duration)
    }

    /// 멈춰 서서 반대쪽을 본다. 돌아서며 한 번 폴짝한다.
    private mutating func turn(to direction: Double, size: Double) {
        let start = duration
        let pause = SaessagiWalkMotion.turnPause
        face.hold(until: start + pause * 0.25)
        face.add(direction * SaessagiWalkMotion.faceShift * size, at: start + pause * 0.25 + SaessagiWalkMotion.faceTurn)
        bob.hold(until: start + pause * 0.25)
        bob.add(SaessagiWalkMotion.bob * size, at: start + pause * 0.25 + SaessagiWalkMotion.faceTurn / 2)
        bob.add(0, at: start + pause * 0.25 + SaessagiWalkMotion.faceTurn)
        duration = start + pause
        holdAll(until: duration)
    }

    /// 앞을 보며 평소 자세로 돌아온다.
    private mutating func settle() {
        face.add(0, at: duration + SaessagiWalkMotion.faceTurn)
        duration += SaessagiWalkMotion.faceTurn
        holdAll(until: duration)
    }

    private mutating func holdAll(until time: Double) {
        moverX.hold(until: time)
        bob.hold(until: time)
        footLeftX.hold(until: time)
        footLeftLift.hold(until: time)
        footRightX.hold(until: time)
        footRightLift.hold(until: time)
        rock.hold(until: time)
        leaf.hold(until: time)
        face.hold(until: time)
    }
}
