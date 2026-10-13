import Foundation
import SwiftData
import Testing
@testable import Daylog

@MainActor
struct RoutineTransferTests {
    private func row(_ title: String = "걷기", group: String = "건강") -> TransferRoutine {
        TransferRoutine(group: group, title: title, weekdays: [1, 3, 5], time: "08:00", note: "")
    }

    @Test func csvAndJSONRoundTripKoreanQuotesCommasAndNewlines() throws {
        var original = row("걷기, \"산책\"")
        original.note = "아침, 저녁\r\n\"따옴표\"와 한글 🐈\n마지막"
        let csv = RoutineTransferFormat.csv([original])
        #expect(try RoutineTransferFormat.decode(csv, isJSON: false) == [original])
        #expect(try RoutineTransferFormat.decode(Data([0xEF, 0xBB, 0xBF]) + csv, isJSON: false) == [original])
        #expect(try RoutineTransferFormat.decode(RoutineTransferFormat.json([original]), isJSON: true) == [original])
    }

    @Test func malformedFilesAndInvalidVersionsAreRejected() throws {
        for text in ["group,title,weekdays,time,note\na,\"unterminated,1,,", "group,title,weekdays,time,note\na,ab\"cd,1,,", "group,title,weekdays,time,note\na,\"x\"z,1,,", "group,title,weekdays,time,note\na,x,1;8,,", "group,title,weekdays,time,note\na,x,1;,,", "group,title,weekdays,time,note\na,x,1,extra,,"] {
            #expect(throws: RoutineTransferError.self) { try RoutineTransferFormat.decode(Data(text.utf8), isJSON: false) }
        }
        for text in ["{\"format\":\"daylog.routines\",\"version\":2,\"routines\":[]}", "{\"format\":\"daylog.backup\",\"version\":1,\"routines\":[]}", "{\"format\":\"daylog.routines\",\"version\":1,\"routines\":[{\"group\":\"g\",\"title\":\"t\",\"weekdays\":\"1\",\"time\":\"\",\"note\":\"\"}]}"] {
            #expect(throws: RoutineTransferError.self) { try RoutineTransferFormat.decode(Data(text.utf8), isJSON: true) }
        }
        #expect(throws: RoutineTransferError.self) { try RoutineTransferFormat.decode(Data([0xFF]), isJSON: false) }
    }

    /// 앱이 내보낸 전체 기록 JSON(`routines`가 없다)을 가져오기로 고르면, 자료형 오류가 아니라 복원할 수 없다고 알려 준다.
    @Test func fullBackupFileIsRejectedWithARestoreMessage() throws {
        let backup = "{\"format\":\"daylog.backup\",\"version\":1,\"schemaVersion\":4,\"entities\":{},\"vacations\":[]}"
        do {
            _ = try RoutineTransferFormat.decode(Data(backup.utf8), isJSON: true)
            Issue.record("전체 기록 JSON이 거부되지 않았다")
        } catch {
            #expect(error.localizedDescription.contains("전체 백업 JSON은 복원할 수 없어요"))
        }
        // 형식이 맞는데 자료형이 틀린 루틴 JSON은 전처럼 자료형을 확인하라고 한다.
        let wrongType = "{\"format\":\"daylog.routines\",\"version\":1,\"routines\":\"x\"}"
        do {
            _ = try RoutineTransferFormat.decode(Data(wrongType.utf8), isJSON: true)
            Issue.record("자료형이 틀린 루틴 JSON이 거부되지 않았다")
        } catch {
            #expect(error.localizedDescription.contains("자료형"))
        }
    }

    @Test func fieldValidationDoesNotTruncateOrRepair() throws {
        var invalid = row()
        invalid.title = String(repeating: "가", count: 61)
        #expect(RoutineTransferFormat.validation(invalid) != nil)
        invalid = row(); invalid.group = "  "
        #expect(RoutineTransferFormat.validation(invalid) != nil)
        invalid = row(); invalid.weekdays = [1, 1]
        #expect(RoutineTransferFormat.validation(invalid) != nil)
        invalid = row(); invalid.title = "걷기\u{0}건강"
        #expect(RoutineTransferFormat.validation(invalid) != nil)
        invalid = row(); invalid.time = "25:99"
        #expect(RoutineTransferFormat.validation(invalid) != nil)
        invalid = row(); invalid.time = "아침 먹고"
        #expect(RoutineTransferFormat.validation(invalid) == nil)
    }

    @Test func previewIsReadOnlyReusesGroupsAndSkipsDuplicates() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "건강")
        try env.routines.add(title: "걷기", timeLabel: "08:00", weekdays: [1, 3, 5], group: group, today: monday)
        let before = try DataExportService(context: env.context).fullJSON(now: .distantPast)
        let preview = try RoutineTransferService(context: env.context).preview([row(), row("물 마시기"), row("물 마시기"), row("독서", group: "학습")], today: monday)
        #expect(preview.createdCount == 2)
        #expect(preview.duplicateCount == 2)
        #expect(preview.newGroupCount == 1)
        #expect(preview.reusedGroupCount == 1)
        #expect(preview.canSave)
        #expect(!env.context.hasChanges)
        #expect(try DataExportService(context: env.context).fullJSON(now: .distantPast) == before)
    }

    @Test func conflictsAndAmbiguousGroupsBlockEntireImport() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "건강")
        try env.routines.add(title: "걷기", timeLabel: "09:00", weekdays: [1, 3, 5], group: group, today: monday)
        let service = RoutineTransferService(context: env.context)
        let conflict = try service.preview([row(), row("새 루틴")], today: monday)
        #expect(conflict.errorCount == 1)
        #expect(!conflict.canSave)
        #expect(throws: RoutineTransferError.self) { try service.commit(conflict, today: monday) }
        #expect(try env.routines.routines().count == 1)
        try env.routines.addGroup(title: "건강")
        #expect(try service.preview([row("새 루틴")], today: monday).errorCount == 1)
    }

    @Test func fileInternalConflictingNamesAreErrors() throws {
        let env = try TestEnv()
        var other = row(); other.time = "09:00"
        let preview = try RoutineTransferService(context: env.context).preview([row(), other], today: monday)
        #expect(preview.errorCount == 1)
        #expect(!preview.canSave)
    }

    @Test func catalogChangeAndMidnightRequireFreshConfirmation() throws {
        let env = try TestEnv()
        let service = RoutineTransferService(context: env.context)
        let preview = try service.preview([row()], today: monday)
        #expect(throws: RoutineTransferError.self) { try service.commit(preview, today: monday.adding(days: 1)) }
        try env.routines.addGroup(title: "외부에서 추가")
        #expect(throws: RoutineTransferError.self) { try service.commit(preview, today: monday) }
        let refreshed = try service.preview(preview.source, today: monday)
        #expect(try service.commit(refreshed, today: monday) == 1)
        #expect(try env.routines.routines().count == 1)
    }

    @Test func batchCommitReusesGroupAndPreservesPastStatisticsAndMeals() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "건강")
        try env.routines.add(title: "기존 루틴", group: group, today: monday)
        let past = try env.log(monday, done: 1)
        past.breakfast = "기존 식사"; try env.context.save()
        let pastStats = try env.stats.period(.all, today: monday)
        let service = RoutineTransferService(context: env.context)
        let today = monday.adding(days: 1)
        let preview = try service.preview([row(), row("독서", group: "학습"), row("영어", group: "학습")], today: today)
        #expect(try service.commit(preview, today: today) == 3)
        #expect(try env.routines.groups().count == 2)
        #expect(try env.routines.routines().count == 4)
        #expect(try env.stats.period(.all, today: monday) == pastStats)
        #expect(past.breakfast == "기존 식사")
        #expect(past.checkList.count == 1)
        #expect(past.checkList.first?.isDone == true)
        let revisions = try env.context.fetch(FetchDescriptor<RoutineRevision>())
        #expect(revisions.filter { $0.effectiveFromKey == today.key }.count == 3)
    }

    @Test func failedBatchRollsBackGroupsRoutinesRevisionsAndSettings() throws {
        enum Failure: Error { case save }
        let env = try TestEnv()
        let before = try DataExportService(context: env.context).fullJSON(now: .distantPast)
        let service = RoutineTransferService(context: env.context, persist: { _ in throw Failure.save })
        let preview = try service.preview([row(), row("독서", group: "학습")], today: monday)
        #expect(throws: Failure.self) { try service.commit(preview, today: monday) }
        #expect(try DataExportService(context: env.context).fullJSON(now: .distantPast) == before)
        #expect(!env.context.hasChanges)
    }

    @Test func directImportDoesNotConsumeUnrelatedDrafts() throws {
        let env = try TestEnv()
        let service = RoutineTransferService(context: env.context)
        let preview = try service.preview([row()], today: monday)
        let record = try env.records.fetchOrCreate(day: monday, today: monday)
        record.breakfast = "아직 저장하지 않음"
        #expect(throws: RoutineTransferError.self) { try service.commit(preview, today: monday) }
        #expect(record.breakfast == "아직 저장하지 않음")
        #expect(try env.routines.routines().isEmpty)
    }

    @Test func exportActiveRoutinesRoundTripsToFreshStore() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "건강")
        try env.routines.add(title: "산책", note: "쉼표, 따옴표 \"\n줄바꿈", timeLabel: "08:00", group: group, today: monday)
        let archived = try env.routines.add(title: "보관", group: group, today: monday)
        try env.routines.setArchived(archived, true, today: monday)
        let service = DataExportService(context: env.context)
        let rows = try RoutineTransferFormat.decode(service.routineJSON(), isJSON: true)
        #expect(rows.count == 1)
        #expect(try RoutineTransferFormat.decode(service.routineCSV(), isJSON: false) == rows)
        let target = try TestEnv()
        let importer = RoutineTransferService(context: target.context)
        try importer.commit(importer.preview(rows, today: monday), today: monday)
        #expect(try DataExportService(context: target.context).activeRoutines() == rows)
    }

    @Test func portableExportRejectsAmbiguousGroupsAndInvalidLegacyValues() throws {
        let env = try TestEnv()
        let first = try env.routines.addGroup(title: "같은 그룹")
        let second = try env.routines.addGroup(title: "같은 그룹")
        try env.routines.add(title: "하나", group: first, today: monday)
        let other = try env.routines.add(title: "둘", group: second, today: monday)
        let exporter = DataExportService(context: env.context)
        #expect(throws: RoutineTransferError.self) { try exporter.routineCSV() }
        _ = try exporter.fullJSON()
        try env.routines.updateGroup(second, title: "다른 그룹", today: monday)
        try env.routines.update(other, timeLabel: "25:99", today: monday)
        #expect(throws: RoutineTransferError.self) { try exporter.routineJSON() }
        _ = try exporter.fullJSON()
    }

    @Test func portableExportRejectsSeparateRoutinesWithIdenticalNamesAndDefinitions() throws {
        let env = try TestEnv()
        let group = try env.routines.addGroup(title: "건강")
        let first = try env.routines.add(title: "걷기", timeLabel: "08:00", weekdays: [1, 3, 5], group: group, today: monday)
        let second = try env.routines.add(title: "걷기", timeLabel: "08:00", weekdays: [1, 3, 5], group: group, today: monday)
        #expect(first.id != second.id)
        let exporter = DataExportService(context: env.context)
        #expect(throws: RoutineTransferError.self) { try exporter.routineCSV() }
        #expect(throws: RoutineTransferError.self) { try exporter.routineJSON() }
        let backup = try #require(JSONSerialization.jsonObject(with: exporter.fullJSON()) as? [String: Any])
        let entities = try #require(backup["entities"] as? [String: [[String: Any]]])
        let ids = Set(entities["RoutineItem"]?.compactMap { $0["id"] as? String } ?? [])
        #expect(ids == Set([first.id.uuidString, second.id.uuidString]))
        #expect(!env.context.hasChanges)
    }

    @Test func portableExportDoesNotRenameMissingGroupToDefault() throws {
        let env = try TestEnv()
        let orphan = RoutineItem(title: "아직 그룹이 없는 루틴", order: 0, groupID: UUID())
        env.context.insert(orphan)
        try env.context.save()
        #expect(throws: RoutineTransferError.self) { try DataExportService(context: env.context).routineJSON() }
        _ = try DataExportService(context: env.context).fullJSON()
    }

    @Test func appStoreImportRefreshesVisibleState() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, clock: { monday })
        store.start()
        let preview = try store.previewRoutineImport(RoutineTransferFormat.json([row()]), isJSON: true)
        #expect(store.confirmRoutineImport(preview))
        #expect(store.routines.count == 1)
        #expect(store.checkSections.flatMap(\.checks).count == 1)
        #expect(store.stats.today.total == 1)
    }
}
