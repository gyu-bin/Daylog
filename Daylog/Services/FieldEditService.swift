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
        // 기기당 최신 편집만 본다.
        var latest: [String: FieldEditSnapshot] = [:]
        for entry in entries where entry.editedAt >= (latest[entry.deviceID]?.editedAt ?? -.infinity) {
            latest[entry.deviceID] = entry
        }
        let candidates = latest.values.sorted { ($0.editedAt, $0.deviceID) < ($1.editedAt, $1.deviceID) }
        guard !candidates.isEmpty else { return nil }

        // 다른 기기가 "이 편집을 보고 나서" 쓴 편집이 있으면, 이 편집은 이미 반영된 과거다.
        var heads = candidates.filter { entry in
            !candidates.contains { other in
                other.deviceID != entry.deviceID && (other.seen[entry.deviceID] ?? -.infinity) >= entry.editedAt
            }
        }
        if heads.isEmpty { heads = candidates }

        var value = heads[0].value
        var isConflict = false
        for head in heads.dropFirst() {
            let merged = TextMerge.merge(value, head.value, separator: separator)
            value = merged.value
            isConflict = isConflict || merged.isConflict
        }
        return Resolution(value: value, needsMerge: Set(heads.map(\.value)).count > 1, isConflict: isConflict)
    }
}

@MainActor
struct FieldEditService {
    let context: ModelContext
    /// 이 저장소(= 이 기기)의 식별자. 동기화되지 않는다.
    let deviceID: String

    func entries(dateKey: String, field: DayTextField) throws -> [FieldEdit] {
        let name = field.rawValue
        return try context.fetch(FetchDescriptor<FieldEdit>(
            predicate: #Predicate { $0.dateKey == dateKey && $0.field == name }
        ))
    }

    /// 이 기기가 그 칸에 `value`를 썼다고 기록한다. 그 순간 알고 있던 다른 기기들의 편집을 함께 적는다.
    func recordEdit(dateKey: String, field: DayTextField, value: String, now: Date = .now) throws {
        let all = try entries(dateKey: dateKey, field: field)
        let mine = all.filter { $0.deviceID == deviceID }.max { $0.editedAt < $1.editedAt }
        let others = all.filter { $0.deviceID != deviceID }
        if let mine, mine.value == value { return }
        // 아무도 쓴 적 없는 칸을 빈 채로 두는 것은 편집이 아니다.
        if mine == nil, others.isEmpty, value.isEmpty { return }

        var seen: [String: Double] = [:]
        for other in others {
            seen[other.deviceID] = max(seen[other.deviceID] ?? -.infinity, other.editedAt.timeIntervalSinceReferenceDate)
        }
        let entry = mine ?? {
            let created = FieldEdit(dateKey: dateKey, field: field.rawValue, deviceID: deviceID)
            context.insert(created)
            return created
        }()
        entry.value = value
        // 같은 기기의 시각은 항상 앞으로만 간다(시계가 뒤로 가도 예전 편집으로 취급되지 않게).
        entry.editedAt = max(now, entry.editedAt.addingTimeInterval(0.001))
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

extension FieldEdit {
    var snapshot: FieldEditSnapshot {
        FieldEditSnapshot(
            deviceID: deviceID, value: value, editedAt: editedAt.timeIntervalSinceReferenceDate, seen: seen
        )
    }
}
