import Foundation
import SwiftData

struct RoutineRate: Equatable, Identifiable, Sendable {
    let routineID: UUID
    let title: String
    let isArchived: Bool
    let done: Int
    let scheduled: Int
    /// 지금 속한 그룹의 색과 이름.
    var colorKey: String = RoutineGroup.defaultColorKey
    var groupID: UUID = RoutineGroup.defaultID
    var groupTitle: String = ""
    /// 삭제한 항목. 지난 기록이 기간 안에 있으면 통계에는 계속 나온다.
    var isRemoved = false

    var id: UUID { routineID }
    var ratio: Double { Achievement.ratio(done: done, total: scheduled) ?? 0 }
    var percent: Int { Achievement.percent(ratio: ratio) }
}

/// 그룹별 달성률. 그룹 이름이 바뀌어도 같은 ID면 한 항목이다.
struct GroupRate: Equatable, Identifiable, Sendable {
    let groupID: UUID
    let title: String
    let colorKey: String
    let isArchived: Bool
    let done: Int
    let scheduled: Int
    var isRemoved = false

    var id: UUID { groupID }
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
    /// 최근 30일의 그룹별 달성률. 각 날짜는 그날 실제로 속해 있던 그룹으로 집계한다.
    var groupRates: [GroupRate]

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
            routineRates: [],
            groupRates: []
        )
    }
}

/// 통계 계산에 필요한 입력을 한 번에 모은 값. 날짜 상태 판정 규칙이 여기 한 곳에만 있다.
struct StatsSource: Sendable {
    struct RecordSummary: Sendable {
        let isRecorded: Bool
        let checks: [(routineID: UUID, isDone: Bool, group: GroupSnapshot)]
    }

    /// 그룹별 집계. `latest`는 기간 안에서 마지막으로 본 그룹 모습(그룹 레코드가 없을 때의 표시용).
    struct GroupTally {
        var done = 0
        var scheduled = 0
        var latest: GroupSnapshot
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

    /// 그룹별 (완료, 예정). 기록이 있는 날은 그날의 스냅샷, 없는 날은 당시 이력의 그룹으로 집계한다.
    func groupTallies(on days: [Day], today: Day) -> [UUID: GroupTally] {
        var tallies: [UUID: GroupTally] = [:]
        func count(_ group: GroupSnapshot, isDone: Bool) {
            var tally = tallies[group.id] ?? GroupTally(latest: group)
            tally.scheduled += 1
            if isDone { tally.done += 1 }
            tally.latest = group
            tallies[group.id] = tally
        }
        for day in days.sorted() {
            guard day <= today, let firstDay, day >= firstDay else { continue }
            if let record = records[day] {
                for check in record.checks { count(check.group, isDone: check.isDone) }
            } else {
                for snapshot in resolver.scheduled(on: day) { count(snapshot.group, isDone: false) }
            }
        }
        return tallies
    }
}

/// 통계 화면의 기간 필터.
enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week, month, quarter, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "7일"
        case .month: return "30일"
        case .quarter: return "90일"
        case .all: return "전체"
        }
    }

    /// "최근 30일 평균"처럼 문장에 넣는 이름.
    var label: String {
        self == .all ? "전체 기간" : "최근 \(title)"
    }

    /// 오늘을 포함한 일수. 전체는 nil(통계 시작일부터).
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }
}

/// 통계 화면이 선택한 기간에 대해 보여 주는 값. 모든 항목이 같은 기간을 기준으로 한다.
struct PeriodStats: Equatable, Sendable {
    var period: StatsPeriod
    var threshold: Int
    var hasStarted: Bool
    /// 기간의 날짜별 결과. 날짜 오름차순.
    var outcomes: [DayOutcome]
    /// 유효한 날(휴식일·시작 전 제외)의 평균 달성률.
    var averagePercent: Int?
    /// 기준 이상을 달성한 날 수 / 유효한 날 수.
    var achievedDays: Int
    var countedDays: Int
    /// 달성률 내림차순.
    var groupRates: [GroupRate]
    var routineRates: [RoutineRate]
    /// 활동 히트맵에 쓰는 날짜별 결과(기간과 최근 90일 중 긴 쪽, 최대 53주). 날짜 오름차순.
    var heatmap: [DayOutcome]

    static func empty(_ period: StatsPeriod) -> PeriodStats {
        PeriodStats(
            period: period, threshold: SettingsService.defaultThreshold, hasStarted: false, outcomes: [],
            averagePercent: nil, achievedDays: 0, countedDays: 0, groupRates: [], routineRates: [], heatmap: []
        )
    }
}

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
        let source = try loadSource(from: min(start, heatmapStart), to: today)
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
            heatmap: Day.range(from: heatmapStart, to: today).map { source.outcome(on: $0, today: today) }
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
            records: summaries
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
