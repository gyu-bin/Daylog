import Foundation

/// 식사 기록 조회와 설정 변경.
extension AppStore {
    // MARK: - 식사 기록 조회

    func mealPage(period: MealPeriod, query: String, offset: Int = 0) -> MealPage {
        var page = MealPage(days: [], nextOffset: nil)
        perform {
            page = try MealHistoryService(context: context).page(period: period, query: query, today: today, offset: offset)
        }
        return page
    }

    /// 선택한 기간의 루틴 통계.
    func periodStats(_ period: StatsPeriod) -> PeriodStats {
        var stats = PeriodStats.empty(period)
        perform { stats = try StatsService(context: context).period(period, today: today) }
        return stats
    }

    /// 그 달에 식사 내용이 있는 날짜들. 식사 기록 캘린더가 쓴다.
    func mealDays(inMonth month: Day) -> Set<Day> {
        var days: Set<Day> = []
        perform { days = try MealHistoryService(context: context).mealDays(inMonth: month, today: today) }
        return days
    }

    func mealSummary(period: MealPeriod) -> MealSummary {
        var summary = MealSummary()
        perform { summary = try MealHistoryService(context: context).summary(period: period, today: today) }
        return summary
    }

    // MARK: - 설정

    func setThreshold(_ value: Int) {
        perform { try SettingsService(context: context).setThreshold(value) }
        reloadStats()
    }
}
