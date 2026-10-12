import Foundation
import SwiftData

/// 휴가는 기록을 바꾸지 않는 날짜 범위다. 양 끝 날짜를 모두 포함한다.
struct VacationPeriod: Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var start: Day
    var end: Day
    var memo: String = ""
    /// 휴가 중에도 이어 갈 루틴. 비어 있으면 전체 휴식이다(이전 버전에서 만든 휴가도 그렇다).
    var keptRoutineIDs: Set<UUID> = []

    func contains(_ day: Day) -> Bool { start <= day && day <= end }
    var keepsRoutines: Bool { !keptRoutineIDs.isEmpty }
}

/// 기존 FieldEdit의 확장 칸에 전체 기간을 저장한다. 새 CloudKit 유형·속성은 필요하지 않다.
/// 기기별 편집과 인과 관계를 유지하며, 서로 못 본 삭제와 수정이 충돌하면 삭제를 따른다.
enum VacationEdit {
    static let dateKey = "vacation"
    static let prefix = "vacation:"

    struct Payload: Codable {
        var version = 1
        var start: String
        var end: String
        var memo: String
        var isRemoved: Bool
        /// 휴가 중 유지할 루틴의 ID. 전체 휴식이면 칸 자체를 쓰지 않아, 이전 형식과 글자까지 같다.
        /// 버전은 올리지 않는다: 이 칸을 모르는 이전 앱도 휴가 자체는 그대로 읽어야 한다(전체 휴식으로 보인다).
        var kept: [String]?

        init(_ period: VacationPeriod, isRemoved: Bool = false) {
            start = period.start.key
            end = period.end.key
            memo = period.memo
            self.isRemoved = isRemoved
            kept = period.keptRoutineIDs.isEmpty ? nil : period.keptRoutineIDs.map(\.uuidString).sorted()
        }

        func period(id: UUID) -> VacationPeriod? {
            guard version == 1, let start = Day(key: start), let end = Day(key: end), start <= end else { return nil }
            let keptIDs = Set((kept ?? []).compactMap { UUID(uuidString: $0) })
            return VacationPeriod(id: id, start: start, end: end, memo: memo, keptRoutineIDs: keptIDs)
        }
    }

    static func fieldName(_ id: UUID) -> String { prefix + id.uuidString }

    static func id(fieldName: String) -> UUID? {
        guard fieldName.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(fieldName.dropFirst(prefix.count)))
    }

    static func encode(_ period: VacationPeriod, isRemoved: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(Payload(period, isRemoved: isRemoved)), as: UTF8.self)
    }

    static func resolve(id: UUID, entries: [FieldEditSnapshot]) -> VacationPeriod? {
        let valid = entries.filter {
            guard let payload = try? JSONDecoder().decode(Payload.self, from: Data($0.value.utf8)) else { return false }
            return payload.period(id: id) != nil
        }
        // 같은 기기·시각의 중복도 입력 순서와 무관하게 판정한다.
        let heads = FieldEditResolver.heads(valid.sorted { $0.value < $1.value })
        let payloads = heads.compactMap { try? JSONDecoder().decode(Payload.self, from: Data($0.value.utf8)) }
        guard !payloads.contains(where: \.isRemoved) else { return nil }
        return payloads.last?.period(id: id)
    }
}

enum VacationError: LocalizedError {
    case invalidRange

    var errorDescription: String? { "종료일은 시작일보다 빠를 수 없습니다." }
}

@MainActor
struct VacationService {
    let context: ModelContext
    var deviceID: String = "read-only"
    /// 저장 실패 복구를 사용자 저장소 없이 검증하기 위한 주입 지점.
    var persist: ((ModelContext) throws -> Void)? = nil

    func periods() throws -> [VacationPeriod] {
        let key = VacationEdit.dateKey
        let entries = try context.fetch(FetchDescriptor<FieldEdit>(predicate: #Predicate { $0.dateKey == key }))
        let grouped = Dictionary(grouping: entries, by: \.field)
        return grouped.compactMap { name, entries in
            guard let id = VacationEdit.id(fieldName: name) else { return nil }
            return VacationEdit.resolve(id: id, entries: entries.map(\.snapshot))
        }.sorted { ($0.start, $0.end, $0.id.uuidString) < ($1.start, $1.end, $1.id.uuidString) }
    }

    func covers(_ day: Day) throws -> Bool { try periods().contains { $0.contains(day) } }

    @discardableResult
    func save(
        id: UUID? = nil, start: Day, end: Day, memo: String = "", keptRoutineIDs: Set<UUID> = []
    ) throws -> VacationPeriod {
        guard start <= end else { throw VacationError.invalidRange }
        let period = VacationPeriod(
            id: id ?? UUID(), start: start, end: end,
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines), keptRoutineIDs: keptRoutineIDs
        )
        try write(period, isRemoved: false)
        return period
    }

    func remove(_ period: VacationPeriod) throws {
        try write(period, isRemoved: true)
    }

    private func write(_ period: VacationPeriod, isRemoved: Bool) throws {
        let service = FieldEditService(context: context, deviceID: deviceID)
        let field = VacationEdit.fieldName(period.id)
        let value = try VacationEdit.encode(period, isRemoved: isRemoved)
        let originals = try service.entries(dateKey: VacationEdit.dateKey, fieldName: field)
            .filter { $0.deviceID == deviceID }
            .map { (entry: $0, value: $0.value, editedAt: $0.editedAt, seenState: $0.seenState) }
        let insertedBefore = Set(context.insertedModelsArray.map { ObjectIdentifier($0) })
        do {
            try service.recordEdit(dateKey: VacationEdit.dateKey, fieldName: field, value: value)
            if let persist { try persist(context) } else { try context.save() }
        } catch {
            // 전체 컨텍스트 rollback은 식사 입력 등 다른 미저장 변경을 잃을 수 있다.
            // 이 작업에서 바꾼 자기 기기의 편집만 되돌리고, 아직 저장되지 않은 새 객체만 취소한다.
            for original in originals {
                original.entry.value = original.value
                original.entry.editedAt = original.editedAt
                original.entry.seenState = original.seenState
            }
            let newlyInserted = context.insertedModelsArray.compactMap { $0 as? FieldEdit }.filter {
                !insertedBefore.contains(ObjectIdentifier($0)) && $0.dateKey == VacationEdit.dateKey
                    && $0.field == field && $0.deviceID == deviceID
            }
            for entry in newlyInserted { context.delete(entry) }
            throw error
        }
    }
}
