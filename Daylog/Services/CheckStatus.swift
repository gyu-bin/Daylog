import Foundation
import SwiftData

/// 하루 한 루틴의 상태. 완료 여부(`DayCheck.isDone`)에 "건너뛰기"를 더한 값이다.
///
/// 건너뛰기는 새 속성이 아니라 체크의 기기별 편집 기록(`FieldEdit`, 칸 이름 `check:<루틴 ID>`)의 값으로만 남긴다.
/// 그래서 저장 형식(SwiftData·CloudKit 스키마)은 그대로다. 건너뛴 체크의 `isDone`은 false라서,
/// 이 값을 모르는 예전 앱에는 미완료로 보이고 달성률도 새 앱과 같게 계산된다.
enum CheckStatus: String, Equatable, Sendable {
    /// 아직 체크하지 않았다.
    case pending
    case done
    /// 사용자가 쉬기로 했다. 달성률에서는 미완료와 같이 미달성이다.
    case skipped
}

extension CheckEdit {
    /// 건너뛰기를 뜻하는 편집 값. 예전 앱은 `"1"`이 아니므로 미완료로 읽는다.
    static let skippedValue = "skip"

    static func value(_ status: CheckStatus) -> String {
        switch status {
        case .pending: return value(false)
        case .done: return value(true)
        case .skipped: return skippedValue
        }
    }

    static func status(value: String) -> CheckStatus {
        switch value {
        case Self.value(true): return .done
        case skippedValue: return .skipped
        default: return .pending
        }
    }

    /// 남은 편집 중 가장 나중 것의 상태. 완료 여부를 정하는 `resolve`와 같은 편집을 고른다.
    static func status(_ entries: [FieldEditSnapshot]) -> CheckStatus? {
        FieldEditResolver.heads(entries).last.map { status(value: $0.value) }
    }
}

extension FieldEditService {
    /// 이 기기가 그 날짜의 체크를 이 상태로 정했다고 기록한다.
    func recordCheck(dateKey: String, routineID: UUID, status: CheckStatus, now: Date = .now) throws {
        try recordEdit(dateKey: dateKey, fieldName: CheckEdit.fieldName(routineID), value: CheckEdit.value(status), now: now)
    }

    /// 저장된 체크의 상태. 완료 표시가 있으면 편집 기록이 무엇이든 완료다(완료를 잃지 않는다).
    func status(of check: DayCheck, dateKey: String) throws -> CheckStatus {
        if check.isDone { return .done }
        return try skippedRoutines(dateKey: dateKey).contains(check.routineID) ? .skipped : .pending
    }

    /// 그 날짜에 건너뛴 루틴.
    func skippedRoutines(dateKey: String) throws -> Set<UUID> {
        try skippedRoutines(from: dateKey, to: dateKey)[dateKey] ?? []
    }

    /// 양 끝을 포함한 기간의 날짜별 건너뛴 루틴. 건너뛴 적이 없는 날짜는 들어 있지 않다.
    func skippedRoutines(from: String, to: String) throws -> [String: Set<UUID>] {
        let skipped = CheckEdit.skippedValue
        // 건너뛰기는 드물다. 먼저 그 값을 가진 줄만 찾고, 있는 날짜에 한해서 다른 기기의 편집까지 읽어 판정한다.
        let marked = try context.fetch(FetchDescriptor<FieldEdit>(
            predicate: #Predicate { $0.value == skipped && $0.dateKey >= from && $0.dateKey <= to }
        )).filter { CheckEdit.routineID(fieldName: $0.field) != nil }
        guard !marked.isEmpty else { return [:] }

        let dateKeys = Array(Set(marked.map(\.dateKey)))
        let fields = Set(marked.map { "\($0.dateKey)|\($0.field)" })
        let related = try context.fetch(FetchDescriptor<FieldEdit>(predicate: #Predicate { dateKeys.contains($0.dateKey) }))
            .filter { fields.contains("\($0.dateKey)|\($0.field)") }

        var result: [String: Set<UUID>] = [:]
        for entries in Dictionary(grouping: related, by: { "\($0.dateKey)|\($0.field)" }).values {
            guard let first = entries.first, let routineID = CheckEdit.routineID(fieldName: first.field),
                  CheckEdit.status(entries.map(\.snapshot)) == .skipped else { continue }
            result[first.dateKey, default: []].insert(routineID)
        }
        return result
    }
}
