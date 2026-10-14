import Foundation

/// 새싹이의 주간 회고: 가장 최근에 끝난 한 주의 요약과, 그 앞 주와의 비교.
///
/// 새로 셈하는 규칙은 없다. 날짜별 결과·루틴별 완료 일수는 통계(`StatsService`)의 것을, 실천한 날은 이번 주의 성장과 같은 판정
/// (`WeeklyGrowthCalculator.isPracticed`)을, XP는 새싹이 성장의 규칙(`GrowthCalculator`)을 그대로 쓴다.
/// 그래서 같은 날짜의 기록·같은 루틴의 체크는 한 번만 세고, 건너뛰기는 완료가 아니며, 휴가일과 루틴이 없던 날은 대상이 아니다.
struct WeeklyReview: Equatable, Sendable {
    /// 회고하는 주(끝난 주)의 첫날과 마지막 날.
    let start: Day
    let end: Day
    /// 그 주의 날짜별 결과(7일).
    let days: [DayOutcome]
    /// 그 주에 완료한 루틴 수.
    let completed: Int
    /// 루틴을 하나 이상 완료한 날 수.
    let practicedDays: Int
    /// 그 주에 얻은 XP.
    let xp: Int
    /// 가장 꾸준히 실천한 루틴(완료한 날이 가장 많은 것). 완료가 없으면 nil.
    let topRoutine: TopRoutine?
    /// 앞 주에 완료한 루틴 수. 앞 주에 기록할 루틴이 없었으면(시작 전·휴가·루틴 없음) nil이고 비교하지 않는다.
    let previousCompleted: Int?

    struct TopRoutine: Equatable, Sendable {
        let title: String
        let days: Int
    }

    /// 회고의 분위기. 문구와 새싹이의 움직임을 고른다.
    enum Mood: Equatable, Sendable {
        /// 완료한 루틴이 없다.
        case empty
        /// 한 주 내내 휴가였다(또는 휴가 말고는 루틴이 없었다).
        case vacation
        /// 앞 주보다 늘었다.
        case grew
        /// 앞 주와 비슷하다.
        case steady
        /// 앞 주보다 줄었다.
        case eased
        /// 비교할 앞 주가 없다.
        case fresh
    }

    var periodTitle: String { "\(start.shortTitle) ~ \(end.shortTitle)" }
    /// 앞 주보다 몇 개 더(음수면 덜) 실천했는지.
    var change: Int? { previousCompleted.map { completed - $0 } }
    var hasRecords: Bool { completed > 0 }

    var mood: Mood {
        guard completed > 0 else {
            let vacation = days.filter { $0.status == .vacation }.count
            let eligible = days.filter(WeeklyGrowthCalculator.isEligible).count
            return vacation > 0 && eligible == 0 ? .vacation : .empty
        }
        guard let previous = previousCompleted, let change else { return .fresh }
        // 한두 개 차이(또는 10% 안쪽)는 비슷하게 유지한 것으로 본다.
        if abs(change) <= max(1, previous / 10) { return .steady }
        return change > 0 ? .grew : .eased
    }

    /// 좋은 한 주였는가: 늘었거나 5일 이상 실천했다. 새싹이가 작게 축하한다.
    var isCelebration: Bool { hasRecords && (mood == .grew || practicedDays >= 5) }

    /// 맨 위의 한마디.
    var headline: String {
        switch mood {
        case .empty: return "지난주 기록은 없지만, 이번 주부터 시작해 볼까요?"
        case .vacation: return "지난주는 휴가로 푹 쉬어 갔어요."
        case .grew: return "지난주보다 더 많이 실천했어요! 멋져요!"
        case .steady: return "꾸준함을 이어가고 있어요!"
        case .eased: return "조금 쉬어가도 괜찮아요. 다시 함께해요!"
        case .fresh: return practicedDays >= 4 ? "한 주 동안 꾸준히 노력했네요!" : "지난주에도 작은 습관을 챙겼어요."
        }
    }

    /// 앞 주와의 비교. 비교할 앞 주가 없거나 기록이 없으면 nil.
    var changeNote: String? {
        guard hasRecords, let previous = previousCompleted, let change else { return nil }
        if change > 0 { return "지난주보다 \(change)개 더 실천했어요!" }
        if change == 0 { return "지난주와 같은 \(completed)개를 실천했어요." }
        // 줄었을 때도 탓하지 않는다.
        return mood == .steady
            ? "지난주(\(previous)개)와 비슷하게 실천했어요."
            : "지난주보다 \(-change)개 적었어요. 이번 주에 천천히 이어 가요."
    }

    /// 마무리 응원.
    var cheer: String {
        switch mood {
        case .empty: return "작은 습관 하나부터 함께해요."
        case .vacation: return "충분히 쉬었다면, 이번 주에 다시 함께해요."
        case .eased: return "새싹이는 언제나 곁에서 기다리고 있어요."
        case .grew, .steady, .fresh: return "이번 주에도 함께해요."
        }
    }

    var accessibilityLabel: String {
        var parts = ["새싹이의 주간 회고. \(periodTitle).", headline]
        if hasRecords {
            parts.append("완료한 루틴 \(completed)개, 실천한 날 \(practicedDays)일, 얻은 XP \(xp).")
            if let topRoutine { parts.append("가장 꾸준했던 습관 \(topRoutine.title), \(topRoutine.days)일 실천.") }
        }
        if let changeNote { parts.append(changeNote) }
        parts.append(cheer)
        return parts.joined(separator: " ")
    }
}

enum WeeklyReviewCalculator {
    /// 회고하는 주: 오늘이 든 주의 바로 앞 주(진행 중인 이번 주는 회고하지 않는다).
    static func reviewedWeek(today: Day, weekStart: WeekStart) -> ClosedRange<Day> {
        let lastDay = weekStart.weekStart(containing: today).adding(days: -1)
        return weekStart.weekStart(containing: lastDay)...lastDay
    }

    /// - Parameters:
    ///   - outcomes: 앞 주의 첫날부터 회고하는 주의 마지막 날까지의 날짜별 결과(통계와 같은 값).
    ///   - rates: 회고하는 주의 루틴별 완료 일수(통계의 루틴별 달성률과 같은 값, 달성률 내림차순).
    static func make(week: ClosedRange<Day>, outcomes: [DayOutcome], rates: [RoutineRate]) -> WeeklyReview {
        let previousWeek = week.lowerBound.adding(days: -7)...week.lowerBound.adding(days: -1)
        let current = outcomes.filter { week.contains($0.day) }
        let previous = outcomes.filter { previousWeek.contains($0.day) }
        let counted = current.filter(WeeklyGrowthCalculator.isEligible)
        // 같은 일수면 달성률이 높은 것, 그것도 같으면 루틴 순서가 앞인 것(받은 목록이 이미 그 순서다).
        let top = rates.filter { $0.done > 0 }.enumerated().max { lhs, rhs in
            lhs.element.done != rhs.element.done ? lhs.element.done < rhs.element.done : lhs.offset > rhs.offset
        }?.element
        // 앞 주에 기록할 루틴이 하나라도 있었거나 완료한 것이 있으면 비교한다.
        let previousCounted = previous.filter(WeeklyGrowthCalculator.isEligible)
        let hasPrevious = !previousCounted.isEmpty
        return WeeklyReview(
            start: week.lowerBound,
            end: week.upperBound,
            days: current,
            completed: counted.reduce(0) { $0 + $1.done },
            practicedDays: Set(current.filter(WeeklyGrowthCalculator.isPracticed).map(\.day)).count,
            xp: GrowthCalculator.totalXP(current),
            topRoutine: top.map { WeeklyReview.TopRoutine(title: $0.title, days: $0.done) },
            previousCompleted: hasPrevious ? previousCounted.reduce(0) { $0 + $1.done } : nil
        )
    }
}

extension AppStore {
    /// 회고할 지난주가 있는가: 첫 루틴을 만든 날(통계 시작일)이 지난주의 마지막 날 이전이다.
    /// 처음 쓰는 사용자에게는 카드를 보여 주지 않고, 오래 쉬다 온 사용자에게는 기록이 없어도 보여 준다(기존 설정 값만 쓴다).
    func hasWeekToReview(weekStart: WeekStart) -> Bool {
        guard let firstDay = stats.firstDay else { return false }
        return firstDay <= WeeklyReviewCalculator.reviewedWeek(today: today, weekStart: weekStart).upperBound
    }

    /// 지난주의 회고. 기록이 바뀌거나(동기화 포함) 날짜·주 시작 요일이 바뀌면 다시 계산하고, 그 사이에는 계산해 둔 값을 쓴다.
    func weeklyReview(weekStart: WeekStart) -> WeeklyReview {
        let week = WeeklyReviewCalculator.reviewedWeek(today: today, weekStart: weekStart)
        let key = "\(weekStart.rawValue)|\(today.key)|\(dataVersion)"
        if let cached = weeklyReviewCache, cached.key == key { return cached.review }
        var outcomes: [DayOutcome] = []
        var rates: [RoutineRate] = []
        perform {
            (outcomes, rates) = try StatsService(context: context).review(
                from: week.lowerBound.adding(days: -7), to: week.upperBound, focus: week, today: today
            )
        }
        let review = WeeklyReviewCalculator.make(week: week, outcomes: outcomes, rates: rates)
        weeklyReviewCache = (key, review)
        return review
    }
}
