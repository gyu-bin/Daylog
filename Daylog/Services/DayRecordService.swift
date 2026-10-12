import Foundation
import SwiftData

/// 날짜별 기록의 생성과 수정을 한 곳에서 담당한다.
/// 메인 액터에서만 실행되므로 한 기기 안에서는 같은 날짜의 생성 요청이 겹치지 않는다.
///
/// 저장소에는 고유 제약이 없다(CloudKit 조건). 다른 기기에서 같은 날짜의 기록이 들어와 둘이 될 수 있으므로,
/// 읽을 때는 항상 "대표 기록"을 고른다. 대표는 어느 기기에서든 같은 것이 뽑힌다.
@MainActor
struct DayRecordService {
    let context: ModelContext

    /// 대표 기록을 고르는 순서: 먼저 만들어진 것, 같으면 동기화 식별자 순.
    nonisolated static func precedes(_ lhs: DayRecord, _ rhs: DayRecord) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return SyncOrder.precedes(lhs.syncID, rhs.syncID)
    }

    /// 같은 날짜로 저장된 기록 전부. 대표가 맨 앞.
    func physicalRecords(on day: Day) throws -> [DayRecord] {
        let key = day.key
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.dateKey == key })
        return try context.fetch(descriptor).sorted(by: Self.precedes)
    }

    /// 그 날짜의 대표 기록.
    func record(on day: Day) throws -> DayRecord? {
        try physicalRecords(on: day).first
    }

    /// 양 끝을 포함한 기간의 대표 기록. 날짜 오름차순.
    func records(from: Day, to: Day) throws -> [DayRecord] {
        let lower = from.key
        let upper = to.key
        var descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.dateKey >= lower && $0.dateKey <= upper },
            sortBy: [SortDescriptor(\.dateKey)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.checks]
        var representatives: [String: DayRecord] = [:]
        for record in try context.fetch(descriptor) {
            if let current = representatives[record.dateKey], Self.precedes(current, record) { continue }
            representatives[record.dateKey] = record
        }
        return representatives.values.sorted { $0.dateKey < $1.dateKey }
    }

    /// 날짜의 기록을 불러오거나, 없으면 그날 유효했던 루틴 이력으로 스냅샷을 만들어 저장한다.
    ///
    /// 새로 만든 기록은 `activityAt`이 nil이라 통계에서는 여전히 미기록으로 취급된다.
    func fetchOrCreate(day: Day, today: Day) throws -> DayRecord {
        guard day <= today else { throw DaylogError.futureDate(day.key) }
        if let existing = try record(on: day) { return existing }

        let record = DayRecord(day: day)
        context.insert(record)
        for snapshot in try ScheduleResolver(context: context).scheduled(on: day) {
            record.attach(DayCheck(snapshot: snapshot))
        }
        try context.save()
        return record
    }

    func setDone(_ check: DayCheck, _ isDone: Bool, now: Date = .now) throws {
        check.isDone = isDone
        check.record?.activityAt = now
        try context.save()
    }

    /// 건너뛰기는 완료 표시 없이 남는다(상태 자체는 편집 기록에 있다). 사용자가 정한 것이므로 그날은 기록한 날이 된다.
    func setStatus(_ check: DayCheck, _ status: CheckStatus, now: Date = .now) throws {
        try setDone(check, status == .done, now: now)
    }

    /// 텍스트 입력을 모델에 반영한다. 디스크 저장은 호출한 쪽에서 묶어서 한다.
    func setText(
        _ value: String,
        at keyPath: ReferenceWritableKeyPath<DayRecord, String>,
        of record: DayRecord,
        now: Date = .now
    ) {
        guard record[keyPath: keyPath] != value else { return }
        record[keyPath: keyPath] = value
        record.activityAt = now
    }
}
