import Foundation

/// 유효한 이전 기간의 값만 비교한다. 시작 전·휴가·휴식은 0으로 대체하지 않는다.
struct PreviousPeriodStats: Equatable, Sendable {
    let start: Day
    let end: Day
    let outcomes: [DayOutcome]

    var averagePercent: Int? { StatsCalculator.averagePercent(outcomes) }
    var countedDays: Int { outcomes.filter { $0.ratio != nil }.count }
    var unrecordedDays: Int { outcomes.filter { $0.status == .unrecorded }.count }
}

extension PeriodStats {
    /// 표시된 두 평균 간 퍼센트포인트 차이. 어느 한쪽이라도 집계 불가면 비교 불가다.
    var averageChange: Int? {
        guard let current = averagePercent, let previous = previousPeriod?.averagePercent else { return nil }
        return current - previous
    }

    var unrecordedDays: Int { outcomes.filter { $0.status == .unrecorded }.count }
}
