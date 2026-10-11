import Foundation
import SwiftData

/// Exports raw physical rows, including duplicates/tombstones, without saving or reconciling.
/// Dates are seconds since 2001-01-01T00:00:00Z (Double); Data is base64; absent fields remain JSON null.
@MainActor
struct DataExportService {
    let context: ModelContext

    func activeRoutines() throws -> [TransferRoutine] {
        let service = RoutineService(context: context)
        let groups = try service.groupsByID()
        return try service.routines().compactMap { routine in
            let group = groups[routine.effectiveGroupID]
            guard !routine.isArchived, !(group?.isArchived ?? false) else { return nil }
            guard group != nil || routine.effectiveGroupID == RoutineGroup.defaultID else {
                throw RoutineTransferError.invalid("아직 그룹 정보가 도착하지 않은 루틴이 있어요. 동기화 후 다시 시도하거나 전체 기록 JSON을 저장해 주세요.")
            }
            return TransferRoutine(group: group?.title ?? RoutineGroup.defaultTitle, title: routine.title,
                                   weekdays: routine.weekdays, time: routine.timeLabel, note: routine.note)
        }
    }

    func routineCSV() throws -> Data { try checkedSize(RoutineTransferFormat.csv(portableRows())) }
    func routineJSON() throws -> Data { try checkedSize(RoutineTransferFormat.json(portableRows())) }

    private func checkedSize(_ data: Data) throws -> Data {
        guard data.count <= RoutineTransferFormat.maximumBytes else {
            throw RoutineTransferError.invalid("루틴 파일이 가져오기 한도 5MB를 넘어요. 전체 기록 JSON으로 보관해 주세요.")
        }
        return data
    }

    private func portableRows() throws -> [TransferRoutine] {
        let service = RoutineService(context: context)
        let allGroups = try service.groupsByID()
        var activeGroupIDs: [String: Set<UUID>] = [:]
        for routine in try service.routines() where !routine.isArchived {
            let group = allGroups[routine.effectiveGroupID]
            guard !(group?.isArchived ?? false) else { continue }
            activeGroupIDs[group?.title ?? RoutineGroup.defaultTitle, default: []].insert(routine.effectiveGroupID)
        }
        guard activeGroupIDs.values.allSatisfy({ $0.count == 1 }) else {
            throw RoutineTransferError.invalid("활성 루틴이 속한 서로 다른 그룹의 이름이 같아요. 그룹명을 구별하거나 전체 기록 JSON을 저장해 주세요.")
        }
        let rows = try activeRoutines()
        guard !rows.isEmpty, rows.count <= RoutineTransferFormat.maximumRows else {
            throw RoutineTransferError.invalid("재가져오기 파일은 활성 루틴 1~1,000개를 지원해요. 전체 기록 JSON은 개수 제한 없이 저장할 수 있어요.")
        }
        struct Name: Hashable { let group: String; let title: String }
        var seen: Set<Name> = []
        for row in rows {
            if let error = RoutineTransferFormat.validation(row) {
                throw RoutineTransferError.invalid("\(row.title): \(error) 전체 기록 JSON에는 원본을 그대로 보관할 수 있어요.")
            }
            let key = Name(group: row.group, title: row.title)
            if !seen.insert(key).inserted {
                throw RoutineTransferError.invalid("같은 그룹에 이름이 같은 루틴이 여러 개 있어요. 다시 가져올 때 하나로 합쳐지지 않도록 이름을 구별하거나 전체 기록 JSON을 저장해 주세요.")
            }
        }
        return rows
    }

    /// Detect catalog changes between preview and confirmation, including physical duplicate rows.
    func catalogStamp() throws -> Data {
        try encode(["groups": try ordered(RoutineGroup.self).map(group), "routines": try ordered(RoutineItem.self).map(routine)])
    }

    func fullJSON(now: Date = .now) throws -> Data {
        let records = try ordered(DayRecord.self)
        let checks = try ordered(DayCheck.self)
        let recordIDs = Dictionary(uniqueKeysWithValues: records.enumerated().map { ($1.persistentModelID, "record:\($0)") })
        let checkIDs = Dictionary(uniqueKeysWithValues: checks.enumerated().map { ($1.persistentModelID, "check:\($0)") })
        guard records.allSatisfy({ ($0.checks ?? []).allSatisfy { checkIDs[$0.persistentModelID] != nil } }),
              checks.allSatisfy({ $0.record == nil || recordIDs[$0.record!.persistentModelID] != nil }) else {
            throw RoutineTransferError.invalid("기록 관계를 모두 읽지 못했어요. 동기화가 끝난 뒤 다시 내보내 주세요.")
        }
        let recordRows: [[String: Any]] = records.map { item in
            ["rowID": recordIDs[item.persistentModelID]!, "dateKey": item.dateKey, "date": date(item.date),
             "checks": item.checks.map { $0.map { checkIDs[$0.persistentModelID]! } } as Any? ?? NSNull(),
             "breakfast": item.breakfast, "lunch": item.lunch, "dinner": item.dinner, "snack": item.snack,
             "mealMemo": item.mealMemo, "tomorrowTask": item.tomorrowTask, "activityAt": date(item.activityAt),
             "createdAt": date(item.createdAt), "syncID": uuid(item.syncID), "mergeState": data(item.mergeState)]
        }
        let checkRows: [[String: Any]] = checks.map { item in
            ["rowID": checkIDs[item.persistentModelID]!, "routineID": uuid(item.routineID), "title": item.title,
             "timeLabel": item.timeLabel, "note": item.note, "order": item.order, "isDone": item.isDone,
             "record": item.record.flatMap { recordIDs[$0.persistentModelID] } as Any? ?? NSNull(),
             "isHidden": item.isHidden, "syncID": uuid(item.syncID), "groupID": uuid(item.groupID),
             "groupTitle": item.groupTitle, "groupColorKey": item.groupColorKey, "groupOrder": item.groupOrder]
        }
        let revisions: [[String: Any]] = try ordered(RoutineRevision.self).map { item in
            ["routineID": uuid(item.routineID), "effectiveFromKey": item.effectiveFromKey, "title": item.title,
             "timeLabel": item.timeLabel, "note": item.note, "weekdayMask": item.weekdayMask,
             "isArchived": item.isArchived, "order": item.order, "updatedAt": date(item.updatedAt),
             "syncID": uuid(item.syncID), "groupID": uuid(item.groupID), "groupTitle": item.groupTitle,
             "groupColorKey": item.groupColorKey, "groupOrder": item.groupOrder]
        }
        let edits: [[String: Any]] = try ordered(FieldEdit.self).map { item in
            ["dateKey": item.dateKey, "field": item.field, "deviceID": item.deviceID, "value": item.value,
             "editedAt": date(item.editedAt), "seenState": data(item.seenState), "syncID": uuid(item.syncID)]
        }
        let settings: [[String: Any]] = try ordered(AppSettings.self).map { item in
            ["singletonKey": item.singletonKey, "achieveThreshold": item.achieveThreshold,
             "firstRoutineDate": date(item.firstRoutineDate), "updatedAt": date(item.updatedAt), "syncID": uuid(item.syncID)]
        }
        let vacations: [[String: Any]] = try VacationService(context: context).periods().map {
            ["id": uuid($0.id), "start": $0.start.key, "end": $0.end.key, "memo": $0.memo]
        }
        return try encode([
            "format": "daylog.backup", "version": 1, "schemaVersion": 4, "exportedAt": date(now),
            "dateEncoding": "secondsSince2001-01-01T00:00:00Z", "binaryEncoding": "base64",
            "scope": "Current local data only; cloud data not yet received is not included. Restore is not supported.",
            "entities": ["RoutineGroup": try ordered(RoutineGroup.self).map(group),
                         "RoutineItem": try ordered(RoutineItem.self).map(routine), "RoutineRevision": revisions,
                         "DayRecord": recordRows, "DayCheck": checkRows, "FieldEdit": edits, "AppSettings": settings],
            "vacations": vacations
        ])
    }

    private func ordered<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>()).sorted { String(describing: $0.persistentModelID) < String(describing: $1.persistentModelID) }
    }

    private func group(_ item: RoutineGroup) -> [String: Any] {
        ["id": uuid(item.id), "title": item.title, "colorKey": item.colorKey, "order": item.order,
         "isArchived": item.isArchived, "createdAt": date(item.createdAt), "updatedAt": date(item.updatedAt), "deletedAt": date(item.deletedAt)]
    }

    private func routine(_ item: RoutineItem) -> [String: Any] {
        ["id": uuid(item.id), "title": item.title, "note": item.note, "timeLabel": item.timeLabel,
         "weekdayMask": item.weekdayMask, "order": item.order, "isArchived": item.isArchived,
         "createdAt": date(item.createdAt), "updatedAt": date(item.updatedAt), "groupID": uuid(item.groupID), "deletedAt": date(item.deletedAt)]
    }

    private func date(_ value: Date?) -> Any { value.map { $0.timeIntervalSinceReferenceDate as Any } ?? NSNull() }
    private func uuid(_ value: UUID?) -> Any { value.map { $0.uuidString as Any } ?? NSNull() }
    private func data(_ value: Data?) -> Any { value.map { $0.base64EncodedString() as Any } ?? NSNull() }
    private func encode(_ value: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
}
