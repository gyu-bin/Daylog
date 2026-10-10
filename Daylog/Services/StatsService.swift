import Foundation
import SwiftData

struct RoutineRate: Equatable, Identifiable, Sendable {
    let routineID: UUID
    let title: String
    let isArchived: Bool
    let done: Int
    let scheduled: Int

    var id: UUID { routineID }
    var ratio: Double { Achievement.ratio(done: done, total: scheduled) ?? 0 }
    var percent: Int { Achievement.percent(ratio: ratio) }
}

/// 대시보드와 통계 화면이 함께 쓰는 계산 결과. 기준 날짜는 항상 실제 오늘이다.
struct DashboardStats: Equatable, Sendable {
    var threshold: Int
    var firstDay: Day?
    var today: DayOutcome
    /// 오늘을 포함한 최근 7일. 날짜 오름차순.
    var week: [DayOutcome]
    var weeklyAverage: Int?
    var currentStreak: Int
    var longestStreak: Int
    /// 오늘을 포함한 최근 30일. 날짜 오름차순.
    var trend: [DayOutcome]
    var routineRates: [RoutineRate]

    var hasStarted: Bool { firstDay != nil }

    static func empty(today: Day) -> DashboardStats {
        DashboardStats(
            threshold: SettingsService.defaultThreshold,
            firstDay: nil,
            today: DayOutcome(day: today, status: .preStart, done: 0, total: 0),
            week: [],
            weeklyAverage: nil,
            currentStreak: 0,
            longestStreak: 0,
            trend: [],
            routineRates: []
        )
    }
}

/// 통계 계산에 필요한 입력을 한 번에 모은 값. 날짜 상태 판정 규칙이 여기 한 곳에만 있다.
struct StatsSource: Sendable {
    struct RecordSummary: Sendable {
        let isRecorded: Bool
        let checks: [(routineID: UUID, isDone: Bool)]
    }

    let firstDay: Day?
    let resolver: ScheduleResolver
    let records: [Day: RecordSummary]

    func outcome(on day: Day, today: Day) -> DayOutcome {
        if day > today {
            return DayOutcome(day: day, status: .future, done: 0, total: 0)
        }
        guard let firstDay, day >= firstDay else {
            return DayOutcome(day: day, status: .preStart, done: 0, total: 0)
        }
        if let record = records[day] {
            // 기록이 있으면 스냅샷이 진실이다. 예정에서 빠졌어도 완료한 항목은 스냅샷에 남아 있다.
            let total = record.checks.count
            guard total > 0 else {
                return DayOutcome(day: day, status: .rest, done: 0, total: 0)
            }
            let done = record.checks.filter(\.isDone).count
            return DayOutcome(day: day, status: record.isRecorded ? .recorded : .unrecorded, done: done, total: total)
        }
        // 한 번도 열지 않은 날은 당시의 루틴 이력으로 예정 여부를 판정한다.
        let scheduled = resolver.scheduled(on: day).count
        return DayOutcome(day: day, status: scheduled > 0 ? .unrecorded : .rest, done: 0, total: scheduled)
    }

    /// 루틴별 (완료한 날, 예정된 날). 미기록 예정일은 분모에만 들어간다.
    func routineTallies(on days: [Day], today: Day) -> [UUID: (done: Int, scheduled: Int)] {
        var tallies: [UUID: (done: Int, scheduled: Int)] = [:]
        for day in days {
            guard day <= today, let firstDay, day >= firstDay else { continue }
            if let record = records[day] {
                for check in record.checks {
                    tallies[check.routineID, default: (0, 0)].scheduled += 1
                    if check.isDone { tallies[check.routineID, default: (0, 0)].done += 1 }
                }
            } else {
                for snapshot in resolver.scheduled(on: day) {
                    tallies[snapshot.routineID, default: (0, 0)].scheduled += 1
                }
            }
        }
        return tallies
    }
}

@MainActor
struct StatsService {
    static let weekDays = 7
    static let trendDays = 30

    let context: ModelContext

    /// 양 끝을 포함한 기간의 날짜별 결과. 캘린더처럼 특정 기간만 필요한 화면에서 쓴다.
    func outcomes(from: Day, to: Day, today: Day) throws -> [DayOutcome] {
        let source = try loadSource(from: from, to: min(to, today))
        return Day.range(from: from, to: to).map { source.outcome(on: $0, today: today) }
    }

    func dashboard(today: Day) throws -> DashboardStats {
        let settings = try SettingsService(context: context).existingSettings()
        let threshold = settings?.achieveThreshold ?? SettingsService.defaultThreshold
        let firstDay = settings?.firstRoutineDay

        // 최장 연속 기록은 통계 시작일부터, 추이는 최근 30일. 둘을 덮는 기간을 한 번만 조회한다.
        let trendStart = today.adding(days: -(Self.trendDays - 1))
        let start = min(firstDay ?? trendStart, trendStart)
        let source = try loadSource(from: start, to: today)
        let all = Day.range(from: start, to: today).map { source.outcome(on: $0, today: today) }
        let trend = Array(all.suffix(Self.trendDays))
        let week = Array(all.suffix(Self.weekDays))

        return DashboardStats(
            threshold: threshold,
            firstDay: firstDay,
            today: source.outcome(on: today, today: today),
            week: week,
            weeklyAverage: StatsCalculator.averagePercent(week),
            currentStreak: StatsCalculator.currentStreak(all, today: today, threshold: threshold),
            longestStreak: StatsCalculator.longestStreak(all, threshold: threshold),
            trend: trend,
            routineRates: try routineRates(source: source, days: trend.map(\.day), today: today)
        )
    }

    private func loadSource(from: Day, to: Day) throws -> StatsSource {
        var summaries: [Day: StatsSource.RecordSummary] = [:]
        for record in try DayRecordService(context: context).records(from: from, to: to) {
            guard let day = Day(key: record.dateKey) else { continue }
            summaries[day] = StatsSource.RecordSummary(
                isRecorded: record.isRecorded,
                checks: record.checkList.map { (routineID: $0.routineID, isDone: $0.isDone) }
            )
        }
        return StatsSource(
            firstDay: try SettingsService(context: context).existingSettings()?.firstRoutineDay,
            resolver: try ScheduleResolver(context: context),
            records: summaries
        )
    }

    /// 같은 routineID는 이름이 바뀌어도 한 항목으로 합산하고, 현재 이름으로 표시한다.
    private func routineRates(source: StatsSource, days: [Day], today: Day) throws -> [RoutineRate] {
        let tallies = source.routineTallies(on: days, today: today)
        let routines = try RoutineService(context: context).routines()
        return routines
            .compactMap { routine -> (rate: RoutineRate, order: Int)? in
                guard let tally = tallies[routine.id], tally.scheduled > 0 else { return nil }
                let rate = RoutineRate(
                    routineID: routine.id,
                    title: routine.title,
                    isArchived: routine.isArchived,
                    done: tally.done,
                    scheduled: tally.scheduled
                )
                return (rate, routine.order)
            }
            .sorted { ($0.rate.ratio, -$0.order) > ($1.rate.ratio, -$1.order) }
            .map(\.rate)
    }
}
