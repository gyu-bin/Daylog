import Foundation
import SwiftData

/// 텍스트 카드의 내용을 기존 `FieldEdit`의 확장 칸에 저장한다(휴가와 같은 방식). 새 CloudKit 유형·속성은 필요하지 않다.
/// 기기별 편집과 인과 관계를 그대로 써서, 상대 변경을 보고 고친 편집이 이기고 서로 못 본 삭제와 수정이 겹치면 삭제를 따른다.
/// 이 칸을 모르는 예전 앱은 줄을 그냥 무시한다.
enum DashboardTextEdit {
    static let dateKey = "dashboardText"
    static let prefix = "text:"

    struct Payload: Codable {
        var version = 1
        var title: String
        var body: String
        var isRemoved: Bool

        var text: DashboardText? {
            version == 1 ? DashboardText(title: title, body: body) : nil
        }
    }

    static func fieldName(_ id: UUID) -> String { prefix + id.uuidString }

    static func id(fieldName: String) -> UUID? {
        guard fieldName.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(fieldName.dropFirst(prefix.count)))
    }

    static func encode(_ text: DashboardText, isRemoved: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = Payload(title: text.title, body: text.body, isRemoved: isRemoved)
        return String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    static func resolve(_ entries: [FieldEditSnapshot]) -> DashboardText? {
        func payload(_ entry: FieldEditSnapshot) -> Payload? {
            try? JSONDecoder().decode(Payload.self, from: Data(entry.value.utf8))
        }
        let valid = entries.filter { payload($0)?.text != nil }
        // 같은 기기·시각의 중복도 입력 순서와 무관하게 판정한다.
        let payloads = FieldEditResolver.heads(valid.sorted { $0.value < $1.value }).compactMap(payload)
        guard !payloads.contains(where: \.isRemoved) else { return nil }
        return payloads.last?.text
    }
}

@MainActor
struct DashboardTextService {
    let context: ModelContext
    var deviceID: String = "read-only"
    /// 저장 실패 복구를 사용자 저장소 없이 검증하기 위한 주입 지점.
    var persist: ((ModelContext) throws -> Void)? = nil

    /// 지워지지 않은 텍스트 카드 전부.
    func texts() throws -> [UUID: DashboardText] {
        let key = DashboardTextEdit.dateKey
        let entries = try context.fetch(FetchDescriptor<FieldEdit>(predicate: #Predicate { $0.dateKey == key }))
        var result: [UUID: DashboardText] = [:]
        for (name, entries) in Dictionary(grouping: entries, by: \.field) {
            guard let id = DashboardTextEdit.id(fieldName: name),
                  let text = DashboardTextEdit.resolve(entries.map(\.snapshot)) else { continue }
            result[id] = text
        }
        return result
    }

    func save(id: UUID, title: String, body: String) throws {
        try write(id: id, text: DashboardText.cleaned(title: title, body: body), isRemoved: false)
    }

    /// 줄을 지우지 않고 삭제 표시를 남긴다. 늦게 도착한 다른 기기의 옛 편집이 카드를 되살리지 않는다.
    func remove(id: UUID) throws {
        try write(id: id, text: DashboardText(title: "", body: ""), isRemoved: true)
    }

    private func write(id: UUID, text: DashboardText, isRemoved: Bool) throws {
        let service = FieldEditService(context: context, deviceID: deviceID)
        let field = DashboardTextEdit.fieldName(id)
        let value = try DashboardTextEdit.encode(text, isRemoved: isRemoved)
        let originals = try service.entries(dateKey: DashboardTextEdit.dateKey, fieldName: field)
            .filter { $0.deviceID == deviceID }
            .map { (entry: $0, value: $0.value, editedAt: $0.editedAt, seenState: $0.seenState) }
        let insertedBefore = Set(context.insertedModelsArray.map { ObjectIdentifier($0) })
        do {
            try service.recordEdit(dateKey: DashboardTextEdit.dateKey, fieldName: field, value: value)
            if let persist { try persist(context) } else { try context.save() }
        } catch {
            // 다른 미저장 변경(식사 입력 등)을 잃지 않게, 이 작업에서 바꾼 자기 기기의 편집만 되돌린다.
            for original in originals {
                original.entry.value = original.value
                original.entry.editedAt = original.editedAt
                original.entry.seenState = original.seenState
            }
            let newlyInserted = context.insertedModelsArray.compactMap { $0 as? FieldEdit }.filter {
                !insertedBefore.contains(ObjectIdentifier($0)) && $0.dateKey == DashboardTextEdit.dateKey
                    && $0.field == field && $0.deviceID == deviceID
            }
            for entry in newlyInserted { context.delete(entry) }
            throw error
        }
    }
}
