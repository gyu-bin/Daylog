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
