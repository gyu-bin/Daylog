import Foundation
import SwiftData

@MainActor
struct StatsService {
    static let weekDays = 7
    static let trendDays = 30
    /// 히트맵이 보여 주는 최소·최대 일수.
    static let heatmapMinimumDays = 90
    static let heatmapMaximumDays = 371

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
            routineRates: try routineRates(source: source, days: trend.map(\.day), today: today),
            groupRates: try groupRates(source: source, days: trend.map(\.day), today: today, byRate: false)
        )
    }

    /// 선택한 기간의 통계. 기간과 히트맵을 덮는 범위를 한 번만 조회한다.
    func period(_ period: StatsPeriod, today: Day) throws -> PeriodStats {
        let settings = try SettingsService(context: context).existingSettings()
        let threshold = settings?.achieveThreshold ?? SettingsService.defaultThreshold
        guard let firstDay = settings?.firstRoutineDay, firstDay <= today else {
            var empty = PeriodStats.empty(period)
            empty.threshold = threshold
            return empty
        }

        let start = period.days.map { today.adding(days: -($0 - 1)) } ?? firstDay
        let heatmapStart = max(
            min(start, today.adding(days: -(Self.heatmapMinimumDays - 1))),
            today.adding(days: -(Self.heatmapMaximumDays - 1))
        )
        let previousStart = period.days.map { start.adding(days: -$0) }
        let source = try loadSource(from: min(previousStart ?? start, heatmapStart), to: today)
        let outcomes = Day.range(from: start, to: today).map { source.outcome(on: $0, today: today) }
        let days = outcomes.map(\.day)

        return PeriodStats(
            period: period,
            threshold: threshold,
            hasStarted: true,
            outcomes: outcomes,
            averagePercent: StatsCalculator.averagePercent(outcomes),
            achievedDays: outcomes.filter { $0.isAchieved(threshold: threshold) }.count,
            countedDays: outcomes.filter { $0.ratio != nil }.count,
            groupRates: try groupRates(source: source, days: days, today: today, byRate: true),
            routineRates: try routineRates(source: source, days: days, today: today),
            heatmap: Day.range(from: heatmapStart, to: today).map { source.outcome(on: $0, today: today) },
            previousPeriod: previousStart.map { previousStart in
                let end = start.adding(days: -1)
                let previous = Day.range(from: previousStart, to: end).map { source.outcome(on: $0, today: today) }
                return PreviousPeriodStats(start: previousStart, end: end, outcomes: previous)
            }
        )
    }

    private func loadSource(from: Day, to: Day) throws -> StatsSource {
        var summaries: [Day: StatsSource.RecordSummary] = [:]
        for record in try DayRecordService(context: context).records(from: from, to: to) {
            guard let day = Day(key: record.dateKey) else { continue }
            summaries[day] = StatsSource.RecordSummary(
                isRecorded: record.isRecorded,
                checks: record.checkList.map { (routineID: $0.routineID, isDone: $0.isDone, group: $0.group) }
            )
        }
        return StatsSource(
            firstDay: try SettingsService(context: context).existingSettings()?.firstRoutineDay,
            resolver: try ScheduleResolver(context: context),
            records: summaries,
            vacations: try VacationService(context: context).periods()
        )
    }

    /// 같은 routineID는 이름이 바뀌어도 한 항목으로 합산하고, 현재 이름으로 표시한다. 달성률 내림차순.
    /// 삭제한 항목도 기간 안에 지난 기록이 있으면 나온다(지웠다고 지난 통계가 달라지지 않는다).
    private func routineRates(source: StatsSource, days: [Day], today: Day) throws -> [RoutineRate] {
        let tallies = source.routineTallies(on: days, today: today)
        let service = RoutineService(context: context)
        let groups = Dictionary(uniqueKeysWithValues: try service.groups(includingRemoved: true).map { ($0.id, $0) })
        return try service.routines(includingRemoved: true)
            .compactMap { routine -> (rate: RoutineRate, order: Int)? in
                guard let tally = tallies[routine.id], tally.scheduled > 0 else { return nil }
                let group = groups[routine.effectiveGroupID]
                let rate = RoutineRate(
                    routineID: routine.id,
                    title: routine.title,
                    isArchived: routine.isArchived,
                    done: tally.done,
                    scheduled: tally.scheduled,
                    colorKey: group?.colorKey ?? RoutineGroup.defaultColorKey,
                    groupID: routine.effectiveGroupID,
                    groupTitle: group?.title ?? RoutineGroup.defaultTitle,
                    isRemoved: routine.isRemoved || (group?.isRemoved ?? false)
                )
                return (rate, routine.order)
            }
            .sorted { ($0.rate.ratio, -$0.order) > ($1.rate.ratio, -$1.order) }
            .map(\.rate)
    }

    /// 같은 그룹 ID는 이름·색이 바뀌어도 한 항목으로 합산하고, 현재 이름과 색으로 표시한다.
    /// `byRate`면 달성률 내림차순, 아니면 그룹 순서대로.
    private func groupRates(source: StatsSource, days: [Day], today: Day, byRate: Bool) throws -> [GroupRate] {
        let tallies = source.groupTallies(on: days, today: today)
        let groups = try RoutineService(context: context).groups(includingRemoved: true)
        let current = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        let position = Dictionary(uniqueKeysWithValues: groups.enumerated().map { ($1.id, $0) })
        let rates = tallies
            .filter { $0.value.scheduled > 0 }
            .map { id, tally -> GroupRate in
                let group = current[id]
                return GroupRate(
                    groupID: id,
                    title: group?.title ?? tally.latest.title,
                    colorKey: group?.colorKey ?? tally.latest.colorKey,
                    isArchived: group?.isArchived ?? false,
                    done: tally.done,
                    scheduled: tally.scheduled,
                    isRemoved: group?.isRemoved ?? false
                )
            }
        return rates.sorted { lhs, rhs in
            let left = (position[lhs.groupID] ?? Int.max, lhs.title, lhs.groupID.uuidString)
            let right = (position[rhs.groupID] ?? Int.max, rhs.title, rhs.groupID.uuidString)
            if byRate, lhs.ratio != rhs.ratio { return lhs.ratio > rhs.ratio }
            return left < right
        }
    }
}
