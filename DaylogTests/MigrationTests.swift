import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 테스트 번들에 든 고정 저장소를 임시 폴더로 복사해 쓴다. 원본은 건드리지 않는다.
enum Fixture {
    private final class Locator {}

    static func url(_ name: String, _ ext: String) throws -> URL {
        try #require(Bundle(for: Locator.self).url(forResource: name, withExtension: ext))
    }

    /// v1.1 형식 저장소의 사본. 정보 파일이 없는 상태(v1.1 앱이 남긴 그대로)다.
    static func copyOfV1Store() throws -> (directory: URL, store: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylogMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = directory.appendingPathComponent("Daylog.store")
        try FileManager.default.copyItem(at: try url("v1_1", "store"), to: store)
        return (directory, store)
    }

    /// v1.2 형식 저장소의 사본(중복 날짜·편집 기록·숨김 체크 포함).
    static func copyOfV2Store() throws -> (directory: URL, store: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylogMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = directory.appendingPathComponent("Daylog.store")
        try FileManager.default.copyItem(at: try url("v1_2", "store"), to: store)
        return (directory, store)
    }

    static func expectedV2Snapshot() throws -> FixtureSnapshot {
        try JSONDecoder().decode(FixtureSnapshot.self, from: Data(contentsOf: try url("v1_2.expected", "json")))
    }

    static func expectedV1Snapshot() throws -> FixtureSnapshot {
        try JSONDecoder().decode(FixtureSnapshot.self, from: Data(contentsOf: try url("v1_1.expected", "json")))
    }

    static let today = day("2026-10-10")
}

/// 15. 데이터 마이그레이션: v1.1 저장소 → v1.2 형식
@MainActor
struct MigrationTests {
    @Test func v1StoreMigratesWithoutLosingAnything() throws {
        let (directory, storeURL) = try Fixture.copyOfV1Store()
        defer { try? FileManager.default.removeItem(at: directory) }
        let expected = try Fixture.expectedV1Snapshot()

        let container = try DaylogStore.makeContainer(.file(storeURL))
        var migrated = try FixtureSnapshot.capture(context: container.mainContext, today: Fixture.today)
        migrated.fieldEdits = nil // v1.1에는 편집 기록이 없었다

        // 기록 수, 루틴 UUID, 날짜 키, 체크 상태, 식사 기록, 변경 이력, 설정, 통계가 모두 그대로다.
        #expect(migrated.routines == expected.routines)
        #expect(migrated.revisions == expected.revisions)
        #expect(migrated.records == expected.records)
        #expect(migrated.settingsCount == expected.settingsCount)
        #expect(migrated.stats == expected.stats)
        #expect(migrated == expected)
        #expect(expected.records.count == 18)
        #expect(expected.stats.threshold == 70)
    }

    @Test func migrationFillsSyncIdentifiersOnce() throws {
        let (directory, storeURL) = try Fixture.copyOfV1Store()
        defer { try? FileManager.default.removeItem(at: directory) }

        var firstIDs: [String: UUID] = [:]
        do {
            let container = try DaylogStore.makeContainer(.file(storeURL))
            let context = container.mainContext
            let records = try context.fetch(FetchDescriptor<DayRecord>())
            #expect(records.allSatisfy { $0.syncID != nil })
            #expect(Set(records.compactMap(\.syncID)).count == records.count)
            #expect(try context.fetch(FetchDescriptor<DayCheck>()).allSatisfy { $0.syncID != nil && !$0.isHidden })
            #expect(try context.fetch(FetchDescriptor<RoutineRevision>()).allSatisfy { $0.syncID != nil })
            #expect(try context.fetch(FetchDescriptor<AppSettings>()).allSatisfy { $0.syncID != nil })
            #expect(try context.fetch(FetchDescriptor<RoutineItem>()).allSatisfy { $0.updatedAt == $0.createdAt })
            firstIDs = Dictionary(uniqueKeysWithValues: records.compactMap { record in
                record.syncID.map { (record.dateKey, $0) }
            })
        }

        // 다시 열어도 식별자가 바뀌지 않고, 백업도 다시 만들지 않는다.
        let reopened = try DaylogStore.makeContainer(.file(storeURL))
        let again = try reopened.mainContext.fetch(FetchDescriptor<DayRecord>())
        #expect(Dictionary(uniqueKeysWithValues: again.compactMap { record in record.syncID.map { (record.dateKey, $0) } }) == firstIDs)
        let backups = try FileManager.default.contentsOfDirectory(atPath: StoreBackup.backupsRoot(for: storeURL).path)
        #expect(backups.count == 1)
        let info = try #require(StoreInfo.read(for: storeURL))
        #expect(info.schemaVersion == DaylogStore.schemaVersion)
        #expect(info.cloudKitContainerID == nil)
        // 기기 식별자는 처음 열 때 한 번 정해지고 다시 열어도 그대로다.
        #expect(info.deviceID != nil)
        #expect(DaylogStore.deviceID(for: .file(storeURL)) == info.deviceID)
        _ = try DaylogStore.makeContainer(.file(storeURL))
        #expect(StoreInfo.read(for: storeURL)?.deviceID == info.deviceID)
    }

    @Test func migratedStoreKeepsWorking() throws {
        let (directory, storeURL) = try Fixture.copyOfV1Store()
        defer { try? FileManager.default.removeItem(at: directory) }

        let container = try DaylogStore.makeContainer(.file(storeURL))
        let store = AppStore(container: container, clock: { Fixture.today })
        store.start()

        #expect(store.errorMessage == nil)
        #expect(store.checks.count == 3) // 토요일: 현관 출발, 운동 (러닝), 독서
        #expect(store.checks.filter(\.isDone).count == 2)
        #expect(store.text(\.lunch) == "일반식\n닭가슴살 추가")
        #expect(store.archivedRoutines.map(\.title) == ["영어 단어"])

        store.setDone(routineID: try #require(store.checks.last?.routineID), true)
        store.addRoutine(title: "새 루틴")
        store.setText("저녁 추가", at: \.dinner)
        store.flush()
        #expect(store.stats.today.done == 3)
        #expect(store.stats.today.total == 4)
        #expect(store.errorMessage == nil)
    }

    @Test func freshStoreNeedsNoBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylogMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Daylog.store")

        _ = try DaylogStore.makeContainer(.file(storeURL))
        #expect(!FileManager.default.fileExists(atPath: StoreBackup.backupsRoot(for: storeURL).path))
        #expect(StoreInfo.read(for: storeURL)?.schemaVersion == DaylogStore.schemaVersion)
    }
}

/// 4. 기존 로컬 데이터 보존: 백업과 복원
@MainActor
struct BackupTests {
    @Test func backupIsAnExactVerifiedCopyOfTheOldStore() throws {
        let (directory, storeURL) = try Fixture.copyOfV1Store()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalBytes = try Data(contentsOf: storeURL)
        let originalCounts = try StoreBackup.counts(at: storeURL)
        #expect(originalCounts == StoreBackup.Counts(routines: 5, revisions: 8, records: 18, checks: 63, settings: 1))

        _ = try DaylogStore.makeContainer(.file(storeURL))

        let root = StoreBackup.backupsRoot(for: storeURL)
        let backupDirectory = root.appendingPathComponent(
            try #require(try FileManager.default.contentsOfDirectory(atPath: root.path).first)
        )
        #expect(backupDirectory.lastPathComponent.hasPrefix("Daylog-before-v\(DaylogStore.schemaVersion)-"))
        let backupStore = backupDirectory.appendingPathComponent("Daylog.store")
        // 옮기기 전 상태 그대로다.
        #expect(try Data(contentsOf: backupStore) == originalBytes)
        #expect(try StoreBackup.counts(at: backupStore) == originalCounts)
        try StoreBackup.verifyIntegrity(at: backupStore)
    }

    @Test func backupCanBeRestoredAndOpenedAgain() throws {
        let (directory, storeURL) = try Fixture.copyOfV1Store()
        defer { try? FileManager.default.removeItem(at: directory) }
        let expected = try Fixture.expectedV1Snapshot()

        // 옮긴 뒤 기록을 망가뜨린 상황을 만든다.
        do {
            let container = try DaylogStore.makeContainer(.file(storeURL))
            let store = AppStore(container: container, clock: { Fixture.today })
            store.start()
            store.setText("잘못 덮어쓴 내용", at: \.breakfast)
            for routine in store.activeRoutines { store.setArchived(routine, true) }
            store.flush()
        }

        // 백업을 새 위치로 복원해서 연다.
        let root = StoreBackup.backupsRoot(for: storeURL)
        let backupDirectory = root.appendingPathComponent(
            try #require(try FileManager.default.contentsOfDirectory(atPath: root.path).first)
        )
        let restoredURL = directory.appendingPathComponent("Restored.store")
        try StoreBackup.restore(from: backupDirectory, storeFileName: "Daylog.store", to: restoredURL)

        let restored = try DaylogStore.makeContainer(.file(restoredURL))
        var snapshot = try FixtureSnapshot.capture(context: restored.mainContext, today: Fixture.today)
        snapshot.fieldEdits = nil
        #expect(snapshot == expected)
    }

    @Test func failedOpenRestoresTheOriginalFile() throws {
        let (directory, storeURL) = try Fixture.copyOfV1Store()
        defer { try? FileManager.default.removeItem(at: directory) }

        // 저장소 파일이 SQLite가 아닌 경우: 백업 단계에서 멈추고 원본은 손대지 않는다.
        let garbage = Data("not a database".utf8)
        try garbage.write(to: storeURL)
        #expect(throws: (any Error).self) {
            _ = try DaylogStore.makeContainer(.file(storeURL))
        }
        #expect(try Data(contentsOf: storeURL) == garbage)
        #expect(StoreInfo.read(for: storeURL) == nil)
    }

    /// 다른 프로세스가 저장소를 열고 있으면 백업도 변환도 하지 않고 멈춘다.
    @Test func storeHeldByAnotherProcessIsNotTouched() throws {
        let (directory, storeURL) = try Fixture.copyOfV2Store()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalBytes = try Data(contentsOf: storeURL)

        // 다른 프로세스의 잠금을 흉내 낸다(다른 파일 디스크립터로 잡은 잠금은 같은 프로세스라도 충돌한다).
        let descriptor = open(storeURL.path + ".lock", O_CREAT | O_RDWR, 0o644)
        #expect(flock(descriptor, LOCK_EX | LOCK_NB) == 0)
        #expect(throws: (any Error).self) {
            _ = try DaylogStore.makeContainer(.file(storeURL))
        }
        #expect(try Data(contentsOf: storeURL) == originalBytes)
        #expect(!FileManager.default.fileExists(atPath: StoreBackup.backupsRoot(for: storeURL).path))
        #expect(StoreInfo.read(for: storeURL) == nil)

        // 그쪽이 끝나면 정상적으로 열린다. 같은 프로세스에서는 다시 열어도 된다.
        flock(descriptor, LOCK_UN)
        close(descriptor)
        _ = try DaylogStore.makeContainer(.file(storeURL))
        _ = try DaylogStore.makeContainer(.file(storeURL))
        StoreLock.release(for: storeURL)
    }

    @Test func onlyRecentBackupsAreKept() throws {
        let (directory, storeURL) = try Fixture.copyOfV1Store()
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<(StoreBackup.keptBackups + 3) {
            _ = try StoreBackup.create(for: storeURL, label: "test", now: Date(timeIntervalSince1970: Double(index) * 60))
        }
        let kept = try FileManager.default.contentsOfDirectory(atPath: StoreBackup.backupsRoot(for: storeURL).path)
        #expect(kept.count == StoreBackup.keptBackups)
    }
}
