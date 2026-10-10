import Foundation
import SwiftData

/// `FieldEdit`의 값 복사본.
struct FieldEditSnapshot: Equatable, Sendable {
    var deviceID: String
    var value: String
    var editedAt: Double
    var seen: [String: Double]
}

/// 기기별 편집 기록으로부터 한 칸의 값을 정한다. SwiftData에 의존하지 않는 순수 계산.
enum FieldEditResolver {
    struct Resolution: Equatable {
        /// 칸에 들어가야 할 값.
        var value: String
        /// 다른 편집에 덮이지 않고 남은 편집이 둘 이상이고 내용이 서로 다르다(= 동시 편집).
        var needsMerge: Bool
        /// 서로 다른 내용을 이어 붙였다.
        var isConflict: Bool
    }

    static func resolve(_ entries: [FieldEditSnapshot], separator: String) -> Resolution? {
        let heads = heads(entries)
        guard !heads.isEmpty else { return nil }

        var value = heads[0].value
        var isConflict = false
        for head in heads.dropFirst() {
            let merged = TextMerge.merge(value, head.value, separator: separator)
            value = merged.value
            isConflict = isConflict || merged.isConflict
        }
        return Resolution(value: value, needsMerge: Set(heads.map(\.value)).count > 1, isConflict: isConflict)
    }

    /// 다른 기기의 편집에 덮이지 않고 남은 편집들. 시각 순(같으면 기기 ID 순)이라 어느 기기에서 계산해도 같다.
    static func heads(_ entries: [FieldEditSnapshot]) -> [FieldEditSnapshot] {
        // 기기당 최신 편집만 본다.
        var latest: [String: FieldEditSnapshot] = [:]
        for entry in entries where entry.editedAt >= (latest[entry.deviceID]?.editedAt ?? -.infinity) {
            latest[entry.deviceID] = entry
        }
        let candidates = latest.values.sorted { ($0.editedAt, $0.deviceID) < ($1.editedAt, $1.deviceID) }

        // 다른 기기가 "이 편집을 보고 나서" 쓴 편집이 있으면, 이 편집은 이미 반영된 과거다.
        let heads = candidates.filter { entry in
            !candidates.contains { other in
                other.deviceID != entry.deviceID && (other.seen[entry.deviceID] ?? -.infinity) >= entry.editedAt
            }
        }
        return heads.isEmpty ? candidates : heads
    }
}

/// 체크의 완료 여부를 기기별 편집 기록으로 남기고 판정하는 규칙.
///
/// iCloud는 같은 체크를 두 기기가 다르게 바꾸면 "나중에 동기화한" 쪽으로 덮어쓴다. 그러면 한동안 꺼져 있던 기기가
/// 뒤늦게 올린 옛 완료 표시가 방금 한 해제를 되돌릴 수 있다. 편집 기록은 기기마다 따로 있어 덮어쓰이지 않으므로,
/// 도착 순서와 상관없이 "가장 나중에 사용자가 한 변경"을 고를 수 있다.
/// 칸 이름이 텍스트 칸과 달라서 v1.3.1 이하의 앱은 이 기록을 그냥 무시한다(저장 형식은 그대로다).
enum CheckEdit {
    private static let prefix = "check:"

    static func fieldName(_ routineID: UUID) -> String {
        prefix + routineID.uuidString
    }

    static func routineID(fieldName: String) -> UUID? {
        guard fieldName.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(fieldName.dropFirst(prefix.count)))
    }

    static func value(_ isDone: Bool) -> String {
        isDone ? "1" : "0"
    }

    /// 남은 편집 중 가장 나중 것을 따른다. 서로 못 본 채 한 변경이면 시각이 늦은 쪽, 시각도 같으면 기기 ID가 뒤인 쪽.
    static func resolve(_ entries: [FieldEditSnapshot]) -> Bool? {
        FieldEditResolver.heads(entries).last.map { $0.value == value(true) }
    }
}

@MainActor
struct FieldEditService {
    let context: ModelContext
    /// 이 저장소(= 이 기기)의 식별자. 동기화되지 않는다.
    let deviceID: String

    func entries(dateKey: String, field: DayTextField) throws -> [FieldEdit] {
        try entries(dateKey: dateKey, fieldName: field.rawValue)
    }

    func entries(dateKey: String, fieldName name: String) throws -> [FieldEdit] {
        try context.fetch(FetchDescriptor<FieldEdit>(
            predicate: #Predicate { $0.dateKey == dateKey && $0.field == name }
        ))
    }

    /// 이 기기가 그 칸에 `value`를 썼다고 기록한다. 그 순간 알고 있던 다른 기기들의 편집을 함께 적는다.
    func recordEdit(dateKey: String, field: DayTextField, value: String, now: Date = .now) throws {
        try recordEdit(dateKey: dateKey, fieldName: field.rawValue, value: value, now: now)
    }

    /// 이 기기가 그 날짜의 체크를 완료/해제했다고 기록한다.
    func recordCheck(dateKey: String, routineID: UUID, isDone: Bool, now: Date = .now) throws {
        try recordEdit(dateKey: dateKey, fieldName: CheckEdit.fieldName(routineID), value: CheckEdit.value(isDone), now: now)
    }

    func recordEdit(dateKey: String, fieldName: String, value: String, now: Date = .now) throws {
        let all = try entries(dateKey: dateKey, fieldName: fieldName)
        let mine = all.filter { $0.deviceID == deviceID }.max { $0.editedAt < $1.editedAt }
        let others = all.filter { $0.deviceID != deviceID }
        // 같은 값을 다시 쓰는 것은 편집이 아니다. 단, 그 사이 다른 기기가 고쳤다면 "다시 이 값으로 바꾼" 새 편집이다.
        let supersededAt = others.map(\.editedAt).max() ?? .distantPast
        if let mine, mine.value == value, mine.editedAt >= supersededAt { return }
        // 아무도 쓴 적 없는 칸을 빈 채로 두는 것은 편집이 아니다.
        if mine == nil, others.isEmpty, value.isEmpty { return }

        var seen: [String: Double] = [:]
        for other in others {
            seen[other.deviceID] = max(seen[other.deviceID] ?? -.infinity, other.editedAt.timeIntervalSinceReferenceDate)
        }
        let entry = mine ?? {
            let created = FieldEdit(dateKey: dateKey, field: fieldName, deviceID: deviceID)
            context.insert(created)
            return created
        }()
        entry.value = value
        // 같은 기기의 시각은 항상 앞으로만 간다(시계가 뒤로 가도 예전 편집으로 취급되지 않게).
        // 다른 기기의 편집을 보고 쓴 것이면 그 편집보다도 뒤여야 한다.
        entry.editedAt = max(now, entry.editedAt.addingTimeInterval(0.001), supersededAt.addingTimeInterval(0.001))
        entry.seen = seen
    }

    /// 편집 기록이 둘 이상의 기기에서 온 칸들. (날짜, 칸)별로 묶어 돌려준다.
    func groups() throws -> [(dateKey: String, field: DayTextField, entries: [FieldEdit])] {
        let grouped = Dictionary(grouping: try context.fetch(FetchDescriptor<FieldEdit>())) { "\($0.dateKey)|\($0.field)" }
        return grouped.values.compactMap { entries in
            guard let first = entries.first, let field = DayTextField(rawValue: first.field) else { return nil }
            return (first.dateKey, field, entries)
        }
        .sorted { ($0.dateKey, $0.field.rawValue) < ($1.dateKey, $1.field.rawValue) }
    }
}

extension FieldEditService {
    /// 둘 이상의 기기가 완료 여부를 바꾼 체크들. (날짜, 루틴)별로 묶어 돌려준다.
    /// 한 기기만 바꾼 체크는 판정할 것이 없다(그 기기의 값이 그대로 동기화된다).
    func checkGroups() throws -> [(dateKey: String, routineID: UUID, entries: [FieldEdit])] {
        let grouped = Dictionary(grouping: try context.fetch(FetchDescriptor<FieldEdit>())) { "\($0.dateKey)|\($0.field)" }
        return grouped.values.compactMap { entries in
            guard let first = entries.first,
                  let routineID = CheckEdit.routineID(fieldName: first.field),
                  Set(entries.map(\.deviceID)).count > 1
            else { return nil }
            return (first.dateKey, routineID, entries)
        }
        .sorted { ($0.dateKey, $0.routineID.uuidString) < ($1.dateKey, $1.routineID.uuidString) }
    }
}

extension FieldEdit {
    var snapshot: FieldEditSnapshot {
        FieldEditSnapshot(
            deviceID: deviceID, value: value, editedAt: editedAt.timeIntervalSinceReferenceDate, seen: seen
        )
    }
}
