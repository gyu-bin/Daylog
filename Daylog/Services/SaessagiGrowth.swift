import Foundation

/// 새싹이의 성장 단계. 레벨로 정한다(Lv.25 뒤로도 레벨은 오르지만 모습은 꽃에 머문다).
enum GrowthStage: Int, CaseIterable, Comparable, Sendable {
    case sprout, leaf, flower

    static func < (lhs: GrowthStage, rhs: GrowthStage) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .sprout: return "새싹"
        case .leaf: return "잎사귀"
        case .flower: return "꽃"
        }
    }

    /// 이 단계가 시작되는 레벨.
    var firstLevel: Int {
        switch self {
        case .sprout: return 1
        case .leaf: return 10
        case .flower: return 25
        }
    }

    var pose: SaessagiPose {
        switch self {
        case .sprout: return .growthSprout
        case .leaf: return .growthLeaf
        case .flower: return .growthFlower
        }
    }

    var next: GrowthStage? { GrowthStage(rawValue: rawValue + 1) }

    static func stage(forLevel level: Int) -> GrowthStage {
        allCases.last { level >= $0.firstLevel } ?? .sprout
    }
}

/// 새싹이 성장 카드가 보여 주는 값. 누적 XP 하나에서 모두 계산한다.
struct SaessagiGrowth: Equatable, Sendable {
    let xp: Int

    var level: Int { GrowthCalculator.level(forXP: xp) }
    var stage: GrowthStage { GrowthStage.stage(forLevel: level) }
    /// 이번 레벨에서 모은 XP와 다음 레벨까지 필요한 XP(레벨마다 같다).
    var xpIntoLevel: Int { xp - GrowthCalculator.xp(forLevel: level) }
    var xpForNextLevel: Int { GrowthCalculator.xpPerLevel }
    var progress: Double { Double(xpIntoLevel) / Double(xpForNextLevel) }

    /// 다음 성장 단계까지 남은 XP. 꽃 단계면 nil.
    var xpToNextStage: Int? {
        stage.next.map { GrowthCalculator.xp(forLevel: $0.firstLevel) - xp }
    }

    /// 다음 성장 단계 안내.
    var nextStageNote: String {
        // 아직 한 번도 완료하지 않았다: 다음 단계보다 첫 행동을 알려 준다.
        if xp == 0 { return "루틴을 하나 완료할 때마다 10 XP가 쌓여요." }
        guard let next = stage.next, let remaining = xpToNextStage else { return "꽃이 활짝 피었어요. 꾸준함이 계속 쌓이고 있어요." }
        let verb = next == .flower ? "꽃이 피어요" : "잎사귀로 자라요"
        return "Lv.\(next.firstLevel)에 \(verb) · \(remaining.formatted()) XP 남음"
    }

    var accessibilityLabel: String {
        "새싹이 성장. 레벨 \(level), \(stage.title) 단계. 다음 레벨까지 \(xpIntoLevel) / \(xpForNextLevel) XP. \(nextStageNote)"
    }
}

/// XP 규칙. 저장하지 않고 기존 기록(통계의 날짜별 결과)에서 그때그때 계산한다.
///
/// 날짜별 결과는 같은 날짜의 기록을 하나로, 같은 루틴의 체크를 하나로 합친 뒤의 값이라 중복 기록은 한 번만 센다.
/// 그래서 앱을 다시 켜거나 iCloud에서 같은 기록이 다시 와도 XP가 늘지 않고, 완료를 취소하면 그만큼 줄어든다.
enum GrowthCalculator {
    /// 루틴 하나를 완료했을 때.
    static let routineXP = 10
    /// 그날 예정된 루틴을 모두 완료했을 때 더하는 XP.
    static let perfectDayXP = 20
    /// 레벨 하나에 필요한 XP. Lv.1은 0 XP, Lv.10은 900 XP, Lv.25는 2,400 XP.
    static let xpPerLevel = 100

    /// 하루의 XP. 휴가일·쉬는 날·시작 전·미래는 0이고, 실제로 완료한 루틴이 있는 날만 준다(건너뛰기는 완료가 아니다).
    static func xp(for outcome: DayOutcome) -> Int {
        switch outcome.status {
        case .recorded, .unrecorded:
            guard outcome.done > 0 else { return 0 }
            let perfect = outcome.total > 0 && outcome.done >= outcome.total
            return outcome.done * routineXP + (perfect ? perfectDayXP : 0)
        case .vacation, .rest, .preStart, .future:
            return 0
        }
    }

    /// 누적 XP. 같은 날짜가 여러 번 들어 있어도 한 번만 센다.
    static func totalXP(_ outcomes: [DayOutcome]) -> Int {
        var seen = Set<Day>()
        return outcomes.reduce(0) { total, outcome in
            seen.insert(outcome.day).inserted ? total + xp(for: outcome) : total
        }
    }

    static func level(forXP xp: Int) -> Int { max(xp, 0) / xpPerLevel + 1 }
    static func xp(forLevel level: Int) -> Int { max(level - 1, 0) * xpPerLevel }
}

/// 사용자가 루틴을 완료해 XP를 얻은 순간. 화면이 기뻐하는 반응과 축하를 보여 줄 때 쓴다.
///
/// 이 기기에서 사용자가 직접 완료했을 때만 만든다(앱 실행·동기화·다른 기기의 변경으로는 만들지 않는다).
/// 그래서 지난 기록의 레벨업 축하가 앱을 켤 때마다 되풀이되지 않는다.
struct GrowthEvent: Equatable, Sendable, Identifiable {
    let id = UUID()
    let before: SaessagiGrowth
    let after: SaessagiGrowth

    var gained: Int { after.xp - before.xp }
    /// 이번 완료로 그날의 루틴을 모두 마쳐 추가 XP를 받았다.
    var includesPerfectDay: Bool { gained >= GrowthCalculator.routineXP + GrowthCalculator.perfectDayXP }
    var leveledUp: Bool { after.level > before.level }
    var grewUp: Bool { after.stage > before.stage }

    /// XP가 늘었을 때만 사건이 된다(완료 취소·변화 없음은 반응하지 않는다).
    static func make(before: Int, after: Int) -> GrowthEvent? {
        guard after > before else { return nil }
        return GrowthEvent(before: SaessagiGrowth(xp: before), after: SaessagiGrowth(xp: after))
    }

    /// 레벨이나 성장 단계가 바뀌었을 때 덧붙이는 축하 글.
    var celebration: String? {
        if grewUp { return after.stage == .flower ? "꽃이 피었어요!" : "잎사귀로 자랐어요!" }
        if leveledUp { return "Lv.\(after.level) 달성!" }
        return nil
    }

    /// 덧붙이는 글: 하루 목표 보너스.
    var detail: String? {
        includesPerfectDay ? "오늘 루틴 모두 완료 +\(GrowthCalculator.perfectDayXP) XP" : nil
    }

    static func == (lhs: GrowthEvent, rhs: GrowthEvent) -> Bool { lhs.id == rhs.id }
}

extension AppStore {
    /// 새싹이의 성장. 통계가 이미 계산한 누적 XP에서 나온다.
    var growth: SaessagiGrowth {
        SaessagiGrowth(xp: stats.growthXP + Self.debugGrowthBonus)
    }

    /// 화면 검증용: `-DaylogDebugGrowthBonus 880`처럼 주면 XP에 그만큼 더해 보여 준다(Debug 빌드만. 기록은 바뀌지 않는다).
    private static var debugGrowthBonus: Int {
        #if DEBUG
        max(UserDefaults.standard.integer(forKey: "DaylogDebugGrowthBonus"), 0)
        #else
        0
        #endif
    }
}
