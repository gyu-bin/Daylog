import Foundation

/// 머리말 새싹이가 다음에 할 일을 정한다.
///
/// 비중대로 무작위로만 고르면 숨바꼭질이나 긴 산책이 몇 분씩 안 나올 수 있어서, 한 바퀴의 박자(`cycle`)를 정해 두고
/// 박자 안에서만 무작위로 고른다. 그래서 이동과 제자리 동작이 번갈아 나오고, 한 바퀴(넓은 창에서 약 40~60초)에 한 번은
/// 꼭 긴 산책과 숨바꼭질을 한다. 자리가 좁으면(iPhone) 그 틈 안에서만 끝에서 끝으로 오가고, 사이사이 제자리에서 뛰고
/// 두리번거리고 잎을 흔든다.
struct SaessagiDirector: Equatable, Sendable {
    enum Beat: Equatable, Sendable {
        /// 걸을 자리의 70~90%를 가는 긴 산책.
        case longWalk
        /// 주로 빠른 걸음, 가끔 긴 산책(좁은 자리에서는 절반쯤 제자리 동작).
        case walk
        /// 제자리 동작: 두리번거리기·잎 흔들기·뛰기.
        case flourish
        /// 뛰기: 작게·높이·연달아. 숨바꼭질 다음에는 연달아 뛴다.
        case jump
        /// 단추 쪽 끝으로 가서 숨바꼭질.
        case peek
        /// 잠깐 쉬기(가끔 꾸벅 졸기).
        case rest
    }

    /// 한 바퀴: 산책 → 점프 → 산책 → 두리번·잎 흔들기 → 숨바꼭질(폴짝 뛰어나온다) → 연속 점프 → 잠깐 휴식.
    static let cycle: [Beat] = [.longWalk, .jump, .walk, .flourish, .peek, .jump, .rest]
    /// 뛰기 박자에서 고르는 행동.
    static let jumps: Set<SaessagiAction> = [.hop, .bigHop, .doubleHop]
    /// 쉬기 박자에서 가만히 있을 때 더 쉬는 시간(초).
    static let restPause: ClosedRange<Double> = 1.8...2.8

    /// 다음 박자의 차례.
    private(set) var position = 0
    private(set) var lastAction: SaessagiAction?

    /// 지금 자리(`x`)와 걸을 자리(`range`)에서 다음 행동을 고른다. `flourishes`는 제자리 동작의 비중이다.
    mutating func next(
        x: Double, range: Double, size: Double, canPeek: Bool, flourishes: [SaessagiBehavior.Choice],
        using generator: inout some RandomNumberGenerator
    ) -> SaessagiAction {
        let beat = Self.cycle[position % Self.cycle.count]
        position += 1
        let action = pick(beat, range: range, size: size, canPeek: canPeek, flourishes: flourishes, using: &generator)
        lastAction = action
        return action
    }

    private func pick(
        _ beat: Beat, range: Double, size: Double, canPeek: Bool, flourishes: [SaessagiBehavior.Choice],
        using generator: inout some RandomNumberGenerator
    ) -> SaessagiAction {
        let canTravel = size > 0 && range >= SaessagiWalkMotion.travelMinimum * size
        let isNarrow = range < SaessagiWalkMotion.narrowLane * size
        // 좁은 틈(iPhone)에서도 그 안에서는 끝에서 끝으로 걸어 다닌다.
        let canShuffle = size > 0 && range >= SaessagiWalkMotion.shuffleMinimum * size
        func flourish() -> SaessagiAction { weighted(flourishes, using: &generator) }
        func jump() -> SaessagiAction {
            // 숨바꼭질에서 뛰어나온 다음에는 연달아 뛴다.
            if lastAction == .peek { return .doubleHop }
            return weighted(flourishes.filter { Self.jumps.contains($0.action) }, using: &generator)
        }
        switch beat {
        case .longWalk:
            return canShuffle ? .stroll : flourish()
        case .walk:
            // 옮겨 갈 자리가 없을 만큼 좁으면(iPhone) 그 안에서 몇 걸음 종종거린다(걸을 자리가 아예 없으면 제자리 동작).
            guard canTravel else { return canShuffle ? .walk : flourish() }
            if isNarrow { return Bool.random(using: &generator) ? .dash : flourish() }
            // 긴 산책은 한 바퀴에 이미 한 번 있으니 여기서는 주로 짧게 옮겨 간다.
            return Int.random(in: 0..<10, using: &generator) < 7 ? .dash : .stroll
        case .flourish:
            return flourish()
        case .jump:
            return jump()
        case .peek:
            if canPeek && range >= SaessagiWalkMotion.peekMinimumRange * size { return .peek }
            // 숨을 자리가 없을 만큼 좁으면 그 틈 안에서 반대쪽으로 걸어간다.
            return !canTravel && canShuffle ? .stroll : jump()
        case .rest:
            return Int.random(in: 0..<3, using: &generator) == 0 ? .doze : .stay
        }
    }

    /// 비중대로 고른다. 바로 앞에 한 행동은 다시 고르지 않는다(고를 것이 그것뿐이면 다시 한다).
    private func weighted(
        _ choices: [SaessagiBehavior.Choice], using generator: inout some RandomNumberGenerator
    ) -> SaessagiAction {
        let usable = choices.filter { $0.action.isAvailable && $0.weight > 0 }
        let fresh = usable.filter { $0.action != lastAction }
        let pool = fresh.isEmpty ? usable : fresh
        let total = pool.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return .hop }
        var pick = Int.random(in: 0..<total, using: &generator)
        for choice in pool {
            if pick < choice.weight { return choice.action }
            pick -= choice.weight
        }
        return .hop
    }
}
