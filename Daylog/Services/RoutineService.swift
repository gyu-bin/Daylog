import Foundation
import SwiftData

/// 루틴 정의의 변경. 모든 변경은 루틴 정의 + 변경 이력 + 오늘 기록 동기화를 한 번의 저장으로 묶는다.
///
/// 적용 범위: 과거 기록은 건드리지 않고, 오늘 기록에는 즉시 반영하며, 미래는 새 설정을 따른다.
@MainActor
struct RoutineService {
    static let maxTitleLength = 60
    static let maxTimeLabelLength = 12

    let context: ModelContext

    /// 보관된 루틴을 포함한 전체 루틴. 표시 순서대로.
    /// 같은 `id`가 둘 이상 들어와 있으면(고유 제약이 없다) 나중에 수정된 쪽 하나만 돌려준다.
    func routines() throws -> [RoutineItem] {
        let all = try context.fetch(FetchDescriptor<RoutineItem>())
        return Dictionary(grouping: all, by: \.id)
            .values
            .compactMap { group in
                group.max { ($0.updatedAt ?? $0.createdAt, $0.createdAt) < ($1.updatedAt ?? $1.createdAt, $1.createdAt) }
            }
            .sorted { ($0.order, $0.createdAt, $0.id.uuidString) < ($1.order, $1.createdAt, $1.id.uuidString) }
    }

    /// 오늘 기록을 현재 루틴 정의에 맞춘다. 다른 기기의 변경이 들어온 뒤에 호출한다.
    func syncTodayRecord(today: Day) throws {
        for routine in try routines() {
            try syncTodayRecord(with: routine, today: today)
        }
    }

    @discardableResult
    func add(
        title: String,
        note: String = "",
        timeLabel: String = "",
        weekdays: [Int] = Weekdays.all,
        today: Day,
        now: Date = .now
    ) throws -> RoutineItem {
        let title = try Self.validatedTitle(title)
        let weekdays = try Self.validatedWeekdays(weekdays)
        return try transaction {
            let nextOrder = (try routines().map(\.order).max() ?? -1) + 1
            let routine = RoutineItem(
                title: title,
                note: Self.trimmed(note),
                timeLabel: Self.validatedTimeLabel(timeLabel),
                weekdays: weekdays,
                order: nextOrder,
                createdAt: now
            )
            context.insert(routine)

            let settings = try SettingsService(context: context).settings()
            if settings.firstRoutineDate == nil {
                settings.firstRoutineDate = today.anchorDate
            }
            try applyChange(to: routine, today: today, now: now)
            return routine
        }
    }

    /// nil인 항목은 바꾸지 않는다.
    func update(
        _ routine: RoutineItem,
        title: String? = nil,
        note: String? = nil,
        timeLabel: String? = nil,
        weekdays: [Int]? = nil,
        today: Day,
        now: Date = .now
    ) throws {
        let title = try title.map(Self.validatedTitle)
        let weekdays = try weekdays.map(Self.validatedWeekdays)
        try transaction {
            if let title { routine.title = title }
            if let note { routine.note = Self.trimmed(note) }
            if let timeLabel { routine.timeLabel = Self.validatedTimeLabel(timeLabel) }
            if let weekdays { routine.weekdays = weekdays }
            routine.updatedAt = now
            try applyChange(to: routine, today: today, now: now)
        }
    }

    func setArchived(_ routine: RoutineItem, _ isArchived: Bool, today: Day, now: Date = .now) throws {
        try transaction {
            routine.isArchived = isArchived
            routine.updatedAt = now
            try applyChange(to: routine, today: today, now: now)
        }
    }

    /// `ordered` 순서대로 번호를 다시 매긴다. 목록에 없는 루틴(보관된 루틴 등)은 기존 순서를 유지한 채 뒤에 둔다.
    func reorder(_ ordered: [RoutineItem], today: Day, now: Date = .now) throws {
        try transaction {
            let listed = Set(ordered.map(\.id))
            let rest = try routines().filter { !listed.contains($0.id) }
            for (index, routine) in (ordered + rest).enumerated() where routine.order != index {
                routine.order = index
                routine.updatedAt = now
                try applyChange(to: routine, today: today, now: now)
            }
        }
    }

    // MARK: - 입력 검증

    static func validatedTitle(_ raw: String) throws -> String {
        let title = trimmed(raw)
        guard !title.isEmpty else { throw DaylogError.emptyTitle }
        return String(title.prefix(maxTitleLength))
    }

    static func validatedWeekdays(_ raw: [Int]) throws -> [Int] {
        let weekdays = Array(Set(raw.filter { (1...7).contains($0) })).sorted()
        guard !weekdays.isEmpty else { throw DaylogError.noWeekdays }
        return weekdays
    }

    static func validatedTimeLabel(_ raw: String) -> String {
        String(trimmed(raw).prefix(maxTimeLabelLength))
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 변경 적용

    /// 이미 대기 중인 변경(입력 중이던 텍스트 등)을 먼저 저장한 뒤 `body`를 한 번에 저장한다.
    /// 실패하면 `body`의 변경만 되돌린다.
    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try context.saveIfNeeded()
        do {
            let result = try body()
            try context.save()
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    private func applyChange(to routine: RoutineItem, today: Day, now: Date) throws {
        try recordRevision(for: routine, today: today, now: now)
        try syncTodayRecord(with: routine, today: today)
    }

    private func recordRevision(for routine: RoutineItem, today: Day, now: Date) throws {
        let routineID = routine.id
        let todayKey = today.key
        let revisions = try context.fetch(FetchDescriptor<RoutineRevision>(predicate: #Predicate { $0.routineID == routineID }))
        // 가장 최근 이력 = 적용 시작일이 가장 늦고, 같은 날이면 나중에 고친 것.
        let latest = revisions.max {
            ($0.effectiveFromKey, $0.updatedAt) < ($1.effectiveFromKey, $1.updatedAt)
        }

        if let latest {
            // 오늘(또는 시간대가 앞선 다른 기기 기준으로 이미 내일) 날짜의 이력이 있으면 그 이력을 고쳐 쓴다.
            // 새로 만들면 그 날짜가 됐을 때 예전 설정이 되살아나고, 지우면 다른 기기의 이력을 잃는다.
            if latest.effectiveFromKey >= todayKey {
                latest.apply(routine, now: now)
                return
            }
            if latest.matches(routine) { return }
        }
        context.insert(RoutineRevision(routine: routine, effectiveFrom: today, now: now))
    }

    /// 오늘 기록이 이미 있으면 루틴의 현재 상태를 반영한다. 없으면 나중에 이력으로부터 만들어진다.
    private func syncTodayRecord(with routine: RoutineItem, today: Day) throws {
        guard let record = try DayRecordService(context: context).record(on: today) else { return }
        let routineID = routine.id
        let isScheduled = !routine.isArchived && routine.weekdays.contains(today.weekday)
        let checks = record.physicalChecks.filter { $0.routineID == routineID }

        guard !checks.isEmpty else {
            if isScheduled {
                record.attach(DayCheck(routine: routine))
            }
            return
        }

        // 오늘 대상에서 빠진 항목은 지우지 않고 숨긴다. 이미 완료한 항목은 숨김이어도 기록으로 남아 보인다.
        for check in checks {
            if check.title != routine.title { check.title = routine.title }
            if check.timeLabel != routine.timeLabel { check.timeLabel = routine.timeLabel }
            if check.note != routine.note { check.note = routine.note }
            if check.order != routine.order { check.order = routine.order }
            if check.isHidden == isScheduled { check.isHidden = !isScheduled }
        }
    }
}
