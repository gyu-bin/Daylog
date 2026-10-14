import Foundation

/// 휴가 화면에 적을 값: 오늘이 휴가의 며칠째인지와 전체 일수.
struct VacationRestInfo: Equatable, Sendable {
    var start: Day
    var end: Day
    /// 오늘이 휴가의 며칠째인가(첫날이 1).
    var dayNumber: Int
    var totalDays: Int

    /// 지나간 정도(0…1). 마지막 날에 1이다.
    var progress: Double { totalDays > 0 ? Double(dayNumber) / Double(totalDays) : 0 }
    var title: String { "휴가 \(dayNumber)일째 / 총 \(totalDays)일" }
    var periodTitle: String { start == end ? start.shortTitle : "\(start.shortTitle) ~ \(end.shortTitle)" }

    /// 오늘을 포함하는 휴가. 여럿이 겹치면 먼저 시작한 것(같으면 더 긴 것)을 쓴다. 휴가가 아니면 nil.
    static func make(periods: [VacationPeriod], today: Day) -> VacationRestInfo? {
        let period = periods.filter { $0.contains(today) }
            .min { ($0.start, $1.end) < ($1.start, $0.end) }
        guard let period else { return nil }
        return VacationRestInfo(
            start: period.start, end: period.end,
            dayNumber: period.start.days(until: today) + 1, totalDays: period.start.days(until: period.end) + 1
        )
    }
}
