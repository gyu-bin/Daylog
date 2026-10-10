import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 다른 CloudKit 환경으로 옮길 때: 기록을 동기화 이력 없는 새 저장소로 옮기기
@MainActor
struct StoreReseedTests {
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylogReseed-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 며칠 사용한 저장소: 그룹, 항목(보관·삭제 포함), 변경 이력, 체크, 식사, 편집 기록, 설정.
    private func makeUsedStore(at url: URL) throws {
        let container = try DaylogStore.makeContainer(.file(url))
        let context = container.mainContext
        let routines = RoutineService(context: context)
        let records = DayRecordService(context: context)
        let morning = try routines.addGroup(title: "아침", colorKey: "orange")
        let evening = try routines.addGroup(title: "저녁", colorKey: "purple")
        try routines.add(title: "물", timeLabel: "07:00", group: morning, today: monday)
        let stretch = try routines.add(title: "스트레칭", note: "10분", weekdays: [1, 3, 5], group: morning, today: monday)
        let diary = try routines.add(title: "일기", group: evening, today: monday)
        for offset in 0..<4 {
            let day = monday.adding(days: offset)
            let record = try records.fetchOrCreate(day: day, today: day)
            for check in record.checkList.prefix(offset + 1) { try records.setDone(check, true) }
            records.setText("현미밥 \(offset)", at: \.lunch, of: record)
            try FieldEditService(context: context, deviceID: thisMac)
                .recordEdit(dateKey: day.key, field: .lunch, value: record.lunch)
            if offset == 1 { try routines.update(stretch, title: "가벼운 스트레칭", today: day) }
            if offset == 2 { try routines.setArchived(diary, true, today: day) }
            if offset == 3 { try routines.delete(stretch, today: day) }
        }
        try SettingsService(context: context).setThreshold(70)
        try context.save()
    }

    @Test func rebuildKeepsEveryRecordAndIdentifier() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daylog.store")
        try makeUsedStore(at: url)
        let before = try StoreContent.rows(at: url)
        let info = try #require(StoreInfo.read(for: url))
        #expect(before["ZDAYCHECK"]?.isEmpty == false)
        #expect(before["ZROUTINEREVISION"]?.isEmpty == false)

        try StoreReseed.rebuild(at: url)

        // 모든 표의 모든 열 값(식별자, 날짜, 체크가 속한 기록까지)이 그대로다.
        let after = try StoreContent.rows(at: url)
        #expect(StoreContent.differingTables(before, after).isEmpty)
        #expect(after.keys.sorted() == before.keys.sorted())
        // 기기 식별자가 든 정보 파일도 그대로다.
        #expect(StoreInfo.read(for: url) == info)
        // 임시 폴더를 남기지 않는다.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix("Reseed-") }
        #expect(leftovers.isEmpty)

        // 다시 만든 저장소는 앱에서 그대로 열리고 같은 값을 보여 준다.
        let container = try DaylogStore.makeContainer(.file(url))
        let context = container.mainContext
        // 보관한 항목은 남아 있고, 삭제한 항목은 목록에서 빠진 그대로다.
        #expect(try RoutineService(context: context).routines().map(\.title) == ["물", "일기"])
        #expect(try RoutineService(context: context).routines(includingRemoved: true).count == 3)
        #expect(try SettingsService(context: context).settings().achieveThreshold == 70)
        let stats = try StatsService(context: context).dashboard(today: monday.adding(days: 3))
        #expect(stats.today.done > 0)
        #expect(try DayRecordService(context: context).record(on: monday)?.lunch == "현미밥 0")
    }

    /// 다시 만들기 전에, 자동 정리되지 않는 백업이 남는다. 그 백업으로 되돌리면 원래 내용 그대로다.
    @Test func aKeptBackupIsMadeFirstAndRestores() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daylog.store")
        try makeUsedStore(at: url)
        let before = try StoreContent.rows(at: url)

        let backup = try StoreReseed.backUpAndRebuild(at: url)
        #expect(backup.directory.lastPathComponent.contains(StoreBackup.keepMarker))
        #expect(backup.counts == (try StoreBackup.counts(at: url)))
        let backedUp = backup.directory.appendingPathComponent(url.lastPathComponent)
        #expect(StoreContent.differingTables(before, try StoreContent.rows(at: backedUp)).isEmpty)

        // 백업이 자동 정리에서 살아남는다.
        for index in 0..<(StoreBackup.keptBackups + 2) {
            _ = try StoreBackup.create(for: url, label: "later-\(index)", now: Date(timeIntervalSinceNow: Double(index + 1)))
        }
        #expect(FileManager.default.fileExists(atPath: backup.directory.path))

        // 되돌리기: 저장소를 일부러 바꾼 뒤 백업으로 복원하면 원래 내용이다.
        do {
            let container = try DaylogStore.makeContainer(.file(url))
            let check = try #require(try container.mainContext.fetch(FetchDescriptor<DayCheck>()).first)
            check.isDone.toggle()
            try container.mainContext.save()
        }
        try StoreBackup.restore(backup, to: url)
        #expect(StoreContent.differingTables(before, try StoreContent.rows(at: url)).isEmpty)
    }

    /// 실제 사용 흔적이 많은 예시 저장소(v1.3 형식에서 올라온 것)로도 같다.
    @Test func rebuildKeepsTheMigratedFixture() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daylog.store")
        try FileManager.default.copyItem(at: try Fixture.url("v1_3", "store"), to: url)
        _ = try DaylogStore.makeContainer(.file(url))
        let before = try StoreContent.rows(at: url)

        try StoreReseed.rebuild(at: url)
        #expect(StoreContent.differingTables(before, try StoreContent.rows(at: url)).isEmpty)
    }

    /// 내용 비교는 값이 하나만 달라도 알아챈다(비교가 느슨해서 통과하는 일이 없게).
    @Test func contentComparisonNoticesASingleChange() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daylog.store")
        try makeUsedStore(at: url)
        let before = try StoreContent.rows(at: url)

        do {
            let container = try DaylogStore.makeContainer(.file(url))
            let check = try #require(try container.mainContext.fetch(FetchDescriptor<DayCheck>()).first)
            check.isDone.toggle()
            try container.mainContext.save()
        }
        #expect(StoreContent.differingTables(before, try StoreContent.rows(at: url)) == ["ZDAYCHECK"])
    }

    // MARK: - 언제 다시 올리는가

    private let container = "iCloud.example"

    private func info(environment: String?, reseeded: String? = nil, container: String? = "iCloud.example") -> StoreInfo {
        StoreInfo(schemaVersion: 4, cloudKitContainerID: container, deviceID: "d", cloudKitEnvironment: environment, reseedEnvironment: reseeded)
    }

    private func plan(_ info: StoreInfo?, environment: String?, reupload: Bool, exists: Bool = true, cloud: String? = "iCloud.example") -> CloudEnvironmentPlan {
        CloudEnvironmentPlan.decide(
            storeExists: exists, info: info, cloudKitContainerID: cloud, environment: environment, reuploadAll: reupload
        )
    }

    @Test func reuploadHappensOnlyWhenAskedAndOnlyOnce() {
        // v1.3.4 이하의 저장소(환경 기록 없음): 요청이 없으면 그대로 연다. 새로 설치한 Mac이 다시 올리지 않게.
        #expect(plan(info(environment: nil), environment: "Production", reupload: false) == .proceed)
        // 요청하면 다시 올린다.
        #expect(plan(info(environment: nil), environment: "Production", reupload: true) == .reseed)
        #expect(plan(info(environment: "Production"), environment: "Production", reupload: true) == .reseed)
        // 같은 환경에 이미 다시 올렸으면 또 하지 않는다.
        #expect(plan(info(environment: "Production", reseeded: "Production"), environment: "Production", reupload: true) == .proceed)
    }

    @Test func aStoreFromAnotherEnvironmentIsNotOpenedSilently() {
        #expect(plan(info(environment: "Production"), environment: "Development", reupload: false)
            == .refuse(previous: "Production", current: "Development"))
        #expect(plan(info(environment: "Development"), environment: "Production", reupload: false)
            == .refuse(previous: "Development", current: "Production"))
        #expect(plan(info(environment: "Production"), environment: "Production", reupload: false) == .proceed)
    }

    @Test func localOrNewStoresAreNeverTouched() {
        // iCloud를 쓰지 않는 빌드, 새 저장소, iCloud에 처음 연결하는 저장소.
        #expect(plan(info(environment: "Production"), environment: nil, reupload: true, cloud: nil) == .proceed)
        #expect(plan(nil, environment: "Production", reupload: true, exists: false) == .proceed)
        #expect(plan(info(environment: nil, container: nil), environment: "Production", reupload: true) == .proceed)
    }

    /// v1.3.4 이하가 쓴 정보 파일(새 항목 없음)도 그대로 읽힌다.
    @Test func olderInfoFilesStillDecode() throws {
        let old = #"{"schemaVersion":4,"cloudKitContainerID":"iCloud.example","deviceID":"abc"}"#
        let decoded = try JSONDecoder().decode(StoreInfo.self, from: Data(old.utf8))
        #expect(decoded.deviceID == "abc")
        #expect(decoded.cloudKitEnvironment == nil)
        #expect(decoded.reseedEnvironment == nil)
    }
}
