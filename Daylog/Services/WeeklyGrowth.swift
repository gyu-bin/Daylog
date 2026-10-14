import Foundation

/// "이번 주의 성장" 카드가 보여 주는 값: 이번 주에 실천한 날 수와 목표.
///
/// 실천한 날은 예정된 루틴을 하나라도 완료한 날이다(여러 개를 완료해도 하루, 건너뛰기는 완료가 아니다).
/// 휴가일과 예정된 루틴이 없던 날은 대상이 아니고, 아직 오지 않은 날은 세지 않는다.
/// 날짜별 판정은 통계와 같은 `DayOutcome`을 그대로 쓴다(휴가·루틴 변경 이력이 이미 반영돼 있다). 통계의 규칙은 바꾸지 않는다.
struct WeeklyGrowth: Equatable, Sendable {
    /// 이번 주에 실천한 날 수(주의 첫날부터 오늘까지).
    var practicedDays: Int
    /// 주간 목표(1~7일).
    var goal: Int
    /// 사용자가 고르지 않아 추천값을 쓰고 있다.
    var usesRecommendedGoal: Bool
    /// 오늘 이미 실천했다.
    var practicedToday: Bool
    /// 오늘이 실천 대상인 날이다(휴가가 아니고 예정된 루틴이 있다).
    var isTodayEligible: Bool
    /// 이번 주에 아직 실천할 수 있는 날 수: 오늘(대상이고 아직 실천 전이면)과 남은 날 가운데 루틴이 예정된 날.
    var remainingChances: Int
    /// 루틴이 하나라도 있다.
    var hasRoutines: Bool
    /// 오늘이 휴가다. 목표를 재촉하지 않는다.
    var isOnVacation = false

    var isGoalReached: Bool { practicedDays >= goal }
    var remainingToGoal: Int { max(goal - practicedDays, 0) }
    /// 목표 칸 가운데 채울 개수.
    var filledDots: Int { min(practicedDays, goal) }

    /// 첫 줄: 목표까지 얼마나 남았는지. 실제 기록에서 나온 사실만 말한다.
    var headline: String {
        if !hasRoutines { return "첫 루틴을 만들면 이번 주 실천이 여기에 쌓여요." }
        if isGoalReached { return "이번 주 목표를 달성했어요!" }
        if isOnVacation { return practicedDays > 0 ? "이번 주에 \(practicedDays)일 실천했어요." : "지금은 쉬어 가는 중이에요." }
        if remainingToGoal <= remainingChances { return "이번 주 목표까지 \(remainingToGoal)일 남았어요." }
        // 남은 날로는 목표에 닿지 않는다. 닿을 수 있는 것처럼 말하지 않는다.
        return practicedDays > 0 ? "이번 주에 \(practicedDays)일 실천했어요." : "이번 주는 아직 실천한 날이 없어요."
    }

    /// 둘째 줄: 짧은 응원. 비교나 과장은 하지 않는다.
    var detail: String {
        if !hasRoutines { return "오늘의 루틴에서 작은 습관 하나를 추가해 보세요." }
        if isGoalReached { return "꾸준히 실천한 한 주예요." }
        if isOnVacation { return "휴가 중에는 목표를 잠시 내려놓아도 괜찮아요." }
        if practicedToday { return "오늘도 한 걸음 나아갔어요." }
        if isTodayEligible { return "오늘도 작은 습관 하나부터 시작해 보세요." }
        return remainingChances > 0 ? "다음 루틴이 있는 날에 이어 가요." : "다음 주에 다시 이어 가요."
    }

    var accessibilityLabel: String {
        "이번 주의 성장. 목표 \(goal)일 중 \(practicedDays)일 실천. \(headline) \(detail)"
    }
}

enum WeeklyGrowthCalculator {
    /// 루틴이 없을 때의 목표.
    static let fallbackGoal = 5
    /// 추천 목표의 상한. 매일 하는 루틴이어도 처음부터 주 7일을 목표로 권하지는 않는다.
    static let recommendedLimit = 5

    /// 실천한 날인가: 통계에 들어가는 날(휴가·쉬는 날·시작 전·미래가 아님)이고 하나라도 완료했다.
    static func isPracticed(_ outcome: DayOutcome) -> Bool {
        isEligible(outcome) && outcome.done > 0
    }

    /// 실천 대상인 날인가: 예정된 루틴이 있었고 휴가가 아니다.
    static func isEligible(_ outcome: DayOutcome) -> Bool {
        switch outcome.status {
        case .recorded, .unrecorded: return outcome.total > 0
        case .vacation, .rest, .preStart, .future: return false
        }
    }

    /// 지금의 루틴 일정에 맞춘 추천 목표: 루틴이 있는 요일 수(상한 5일). 루틴이 없으면 5일.
    static func recommendedGoal(routineWeekdays: [[Int]]) -> Int {
        let days = Set(routineWeekdays.flatMap { $0 }.filter { (1...7).contains($0) }).count
        return days == 0 ? fallbackGoal : min(days, recommendedLimit)
    }

    /// - Parameters:
    ///   - outcomes: 오늘을 포함한 최근 날짜들의 결과(`DashboardStats.trend`). 이번 주에 든 날만 쓴다.
    ///   - upcomingEligibleDays: 내일부터의 날짜 가운데 루틴이 예정되고 휴가가 아닌 날. 이번 주에 든 날만 쓴다.
    ///   - chosenGoal: 사용자가 고른 목표. nil이면 `recommendedGoal`.
    static func make(
        outcomes: [DayOutcome], upcomingEligibleDays: [Day], today: Day, weekStart: WeekStart,
        chosenGoal: Int?, recommendedGoal: Int, hasRoutines: Bool
    ) -> WeeklyGrowth {
        let first = weekStart.weekStart(containing: today)
        let last = weekStart.weekEnd(containing: today)
        let week = outcomes.filter { $0.day >= first && $0.day <= today }
        let todayOutcome = week.first { $0.day == today }
        let practicedToday = todayOutcome.map(isPracticed) ?? false
        let isTodayEligible = todayOutcome.map(isEligible) ?? false
        let later = Set(upcomingEligibleDays.filter { $0 > today && $0 <= last }).count
        return WeeklyGrowth(
            practicedDays: Set(week.filter(isPracticed).map(\.day)).count,
            goal: min(max(chosenGoal ?? recommendedGoal, 1), 7),
            usesRecommendedGoal: chosenGoal == nil,
            practicedToday: practicedToday,
            isTodayEligible: isTodayEligible,
            remainingChances: later + (isTodayEligible && !practicedToday ? 1 : 0),
            hasRoutines: hasRoutines
        )
    }
}

extension AppStore {
    /// 이번 주의 성장. 통계가 이미 계산해 둔 최근 날짜의 결과를 쓰므로 따로 조회하지 않고, 체크를 바꾸면 바로 따라온다.
    func weeklyGrowth(weekStart: WeekStart, chosenGoal: Int?) -> WeeklyGrowth {
        let last = weekStart.weekEnd(containing: today)
        let daysLeft = max(today.days(until: last), 0)
        let upcoming = daysLeft > 0
            ? upcomingDays(count: daysLeft + 1).dropFirst()
                .filter { !$0.isVacation && $0.sections.contains { !$0.checks.isEmpty } }.map(\.day)
            : []
        var growth = WeeklyGrowthCalculator.make(
            outcomes: stats.trend, upcomingEligibleDays: Array(upcoming), today: today, weekStart: weekStart,
            chosenGoal: chosenGoal,
            recommendedGoal: WeeklyGrowthCalculator.recommendedGoal(routineWeekdays: activeRoutines.map(\.weekdays)),
            hasRoutines: !activeRoutines.isEmpty
        )
        growth.isOnVacation = isVacation(on: today)
        return growth
    }
}
