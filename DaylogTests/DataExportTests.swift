import Foundation
import SwiftData
import Testing
@testable import Daylog

@MainActor
struct DataExportTests {
    @Test func backupIncludesEveryV4FieldPhysicalDuplicateAndRelationshipWithoutMutation() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "한글, 그룹")
        let routine = try env.routines.add(title: "루틴", note: "메모\n두 줄", group: group, today: monday)
        let record = try env.log(monday, done: 1)
        record.breakfast = "토스트"; record.lunch = "밥"; record.dinner = "국"; record.snack = "과일"
        record.mealMemo = "특수 \"문자\""; record.tomorrowTask = "내일 할 일"
        record.mergeState = Data([0, 1, 255])
        let duplicate = DayRecord(day: monday)
        duplicate.syncID = nil
        env.context.insert(duplicate)
        let duplicateCheck = DayCheck(routine: routine)
        duplicateCheck.syncID = nil
        duplicateCheck.isHidden = true
        duplicate.attach(duplicateCheck)
        let orphan = DayCheck(routine: routine)
        orphan.record = nil
        env.context.insert(orphan)
        let field = FieldEdit(dateKey: monday.key, field: "breakfast", deviceID: "device-a")
        field.value = "토스트"; field.seen = ["device-b": 42.25]
        env.context.insert(field)
        group.deletedAt = Date(timeIntervalSinceReferenceDate: 42.125)
        routine.isArchived = true; routine.deletedAt = Date(timeIntervalSinceReferenceDate: 43.25)
        try env.context.save()
        let vacation = try VacationService(context: env.context, deviceID: "device-a").save(start: monday, end: sunday, memo: "여행")
        let service = DataExportService(context: env.context)
        let before = try service.fullJSON(now: .distantPast)
        let json = try #require(JSONSerialization.jsonObject(with: before) as? [String: Any])
        #expect(json["format"] as? String == "daylog.backup")
        #expect(json["schemaVersion"] as? Int == 4)
        let entities = try #require(json["entities"] as? [String: [[String: Any]]])
        #expect(entities.count == 7)
        // Compare to actual SwiftData schema so a newly added model field cannot silently be dropped.
        for entity in env.container.schema.entities {
            let rows = try #require(entities[entity.name])
            #expect(!rows.isEmpty)
            let expected = Set(entity.properties.map(\.name))
            for row in rows { #expect(expected.isSubset(of: Set(row.keys))) }
        }
        let records = try #require(entities["DayRecord"])
        let checks = try #require(entities["DayCheck"])
        #expect(records.count == 2)
        #expect(checks.count == 3)
        #expect(records.filter { $0["dateKey"] as? String == monday.key }.count == 2)
        #expect(checks.contains { $0["record"] is NSNull })
        let recordIDs = Set(records.compactMap { $0["rowID"] as? String })
        let checkIDs = Set(checks.compactMap { $0["rowID"] as? String })
        for row in records { #expect(Set(row["checks"] as? [String] ?? []).isSubset(of: checkIDs)) }
        for row in checks { if let id = row["record"] as? String { #expect(recordIDs.contains(id)) } }
        let exportedRecord = try #require(records.first { $0["breakfast"] as? String == "토스트" })
        #expect(exportedRecord["mergeState"] as? String == record.mergeState?.base64EncodedString())
        #expect(exportedRecord["date"] as? Double == record.date.timeIntervalSinceReferenceDate)
        #expect(records.contains { $0["syncID"] is NSNull })
        let edits = try #require(entities["FieldEdit"])
        #expect(edits.contains { $0["seenState"] as? String == field.seenState?.base64EncodedString() })
        let vacations = try #require(json["vacations"] as? [[String: Any]])
        #expect(vacations.first?["id"] as? String == vacation.id.uuidString)
        #expect(!env.context.hasChanges)
        #expect(try service.activeRoutines().isEmpty)
        #expect(try service.fullJSON(now: .distantPast) == before)
        #expect(!env.context.hasChanges)
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == 2)
    }

    @Test func exportDoesNotSaveDraftOrCreateEmptySettings() throws {
        let env = try TestEnv()
        let exporter = DataExportService(context: env.context)
        _ = try exporter.fullJSON()
        #expect(try env.context.fetchCount(FetchDescriptor<AppSettings>()) == 0)
        #expect(!env.context.hasChanges)
        let record = try env.records.fetchOrCreate(day: monday, today: monday)
        record.breakfast = "未保存"
        _ = try exporter.fullJSON()
        #expect(env.context.hasChanges)
        let saved = try DayRecordService(context: env.freshContext()).record(on: monday)
        #expect(saved?.breakfast != "未保存")
    }

    @Test func vacationDeletionHistoryIsExportedEvenWhenNoActiveVacationRemains() throws {
        let env = try TestEnv()
        let service = VacationService(context: env.context, deviceID: "a")
        let period = try service.save(start: monday, end: sunday)
        try service.remove(period)
        let data = try DataExportService(context: env.context).fullJSON()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entities = try #require(json["entities"] as? [String: [[String: Any]]])
        #expect((json["vacations"] as? [[String: Any]])?.isEmpty == true)
        let value = try #require(entities["FieldEdit"]?.first?["value"] as? String)
        let payload = try JSONDecoder().decode(VacationEdit.Payload.self, from: Data(value.utf8))
        #expect(payload.isRemoved)
    }
}
