import Foundation
import SwiftData

/// 현재 저장소 형식(v1.3.1). 그룹과 항목에 삭제 시각(`deletedAt`)이 추가됐다.
///
/// 형식을 바꿀 때: 현재 모델을 `DaylogSchemaV<n>.swift`로 동결하고, 여기의 버전을 올리고,
/// `DaylogMigrationPlan`에 단계를 추가하고, `DaylogStore.schemaVersion`을 올린다.
enum DaylogSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            RoutineGroup.self, RoutineItem.self, RoutineRevision.self,
            DayRecord.self, DayCheck.self, AppSettings.self, FieldEdit.self,
        ]
    }
}

enum DaylogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DaylogSchemaV1.self, DaylogSchemaV2.self, DaylogSchemaV3.self, DaylogSchemaV4.self]
    }

    /// 모든 단계가 "추가"뿐이다(새 모델, 기본값이 있거나 optional인 새 속성, 제약 제거).
    /// 기존 값의 변환이 없어 경량 단계로 충분하고, CloudKit 스키마에도 추가만 일어난다.
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: DaylogSchemaV1.self, toVersion: DaylogSchemaV2.self),
            .lightweight(fromVersion: DaylogSchemaV2.self, toVersion: DaylogSchemaV3.self),
            .lightweight(fromVersion: DaylogSchemaV3.self, toVersion: DaylogSchemaV4.self),
        ]
    }
}

/// SwiftData 컨테이너 구성. 기록은 앱 번들이 아니라 사용자의 Application Support에 저장된다.
enum DaylogStore {
    enum Location {
        /// Application Support/Daylog/<name>.store
        case onDisk(name: String)
        case file(URL)
        case inMemory
    }

    /// 저장소 형식이 바뀔 때마다 올린다. 이 값이 저장소 옆의 정보 파일과 다르면 열기 전에 백업한다.
    static let schemaVersion = 4

    static var schema: Schema { Schema(versionedSchema: DaylogSchemaV4.self) }

    /// `cloudKitContainerID`가 nil이면 로컬 전용이다.
    static func makeContainer(_ location: Location, cloudKitContainerID: String? = nil) throws -> ModelContainer {
        switch location {
        case .onDisk(let name):
            return try openStore(at: try storeURL(name: name), cloudKitContainerID: cloudKitContainerID)
        case .file(let url):
            return try openStore(at: url, cloudKitContainerID: cloudKitContainerID)
        case .inMemory:
            // 이름을 매번 다르게 해서 같은 프로세스의 다른 in-memory 컨테이너와 섞이지 않게 한다.
            let configuration = ModelConfiguration(
                UUID().uuidString, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, migrationPlan: DaylogMigrationPlan.self, configurations: [configuration])
        }
    }

    /// 그 저장소의 기기 식별자. 저장소를 연 뒤에 호출한다. 메모리 저장소는 매번 새 값이다.
    static func deviceID(for location: Location) -> String {
        let url: URL?
        switch location {
        case .onDisk(let name): url = try? storeURL(name: name)
        case .file(let fileURL): url = fileURL
        case .inMemory: url = nil
        }
        return url.flatMap { StoreInfo.read(for: $0)?.deviceID } ?? UUID().uuidString
    }

    static func storeURL(name: String) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = support.appendingPathComponent("Daylog", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(name).store")
    }

    // MARK: - 안전하게 열기

    /// 기존 저장소를 새 형식으로 옮기거나 iCloud에 처음 연결할 때는
    /// 1) 검증된 백업을 만들고 2) iCloud 없이 로컬에서만 옮긴 뒤 개수를 확인하고 3) 그다음에 iCloud를 연결한다.
    /// 중간에 실패하면 백업으로 되돌리고 오류를 알린다. 기존 기록을 지우거나 빈 저장소로 대체하지 않는다.
    private static func openStore(at url: URL, cloudKitContainerID: String?) throws -> ModelContainer {
        // 백업이나 형식 변환보다 먼저: 다른 프로세스가 이 저장소를 쓰고 있으면 아무것도 하지 않고 멈춘다.
        try StoreLock.acquire(for: url)
        let exists = FileManager.default.fileExists(atPath: url.path)
        let info = StoreInfo.read(for: url)
        let needsMigration = exists && info?.schemaVersion != schemaVersion
        let isEnablingCloud = exists && cloudKitContainerID != nil && info?.cloudKitContainerID != cloudKitContainerID

        var backup: StoreBackup.Backup?
        if needsMigration || isEnablingCloud {
            backup = try StoreBackup.create(for: url, label: needsMigration ? "before-v\(schemaVersion)" : "before-icloud")
        }

        do {
            if needsMigration || isEnablingCloud {
                try prepareLocally(at: url, expecting: needsMigration ? backup?.counts : nil)
            }
            let container = try container(at: url, cloudKitContainerID: cloudKitContainerID)
            try StoreInfo(
                schemaVersion: schemaVersion,
                cloudKitContainerID: cloudKitContainerID,
                deviceID: info?.deviceID ?? UUID().uuidString
            ).write(for: url)
            return container
        } catch {
            if let backup, needsMigration {
                // 옮기다 만 저장소를 남기지 않는다. 이전 버전의 앱으로는 그대로 다시 열 수 있다.
                try? StoreBackup.restore(backup, to: url)
            }
            throw StoreOpenError(underlying: error, backupDirectory: backup?.directory)
        }
    }

    private static func container(at url: URL, cloudKitContainerID: String?) throws -> ModelContainer {
        let database: ModelConfiguration.CloudKitDatabase = cloudKitContainerID.map { .private($0) } ?? .none
        let configuration = ModelConfiguration("Daylog", schema: schema, url: url, cloudKitDatabase: database)
        return try ModelContainer(for: schema, migrationPlan: DaylogMigrationPlan.self, configurations: [configuration])
    }

    /// iCloud 없이 열어서 형식을 옮기고, 기록 수가 그대로인지 확인하고, 동기화 식별자를 채운다.
    /// 식별자는 반드시 iCloud에 올라가기 전에, 이 기기에서 한 번만 채워야 기기마다 값이 달라지지 않는다.
    private static func prepareLocally(at url: URL, expecting counts: StoreBackup.Counts?) throws {
        let container = try container(at: url, cloudKitContainerID: nil)
        let context = ModelContext(container)

        if let counts {
            let migrated = StoreBackup.Counts(
                routines: try context.fetchCount(FetchDescriptor<RoutineItem>()),
                revisions: try context.fetchCount(FetchDescriptor<RoutineRevision>()),
                records: try context.fetchCount(FetchDescriptor<DayRecord>()),
                checks: try context.fetchCount(FetchDescriptor<DayCheck>()),
                settings: try context.fetchCount(FetchDescriptor<AppSettings>()),
                fieldEdits: try context.fetchCount(FetchDescriptor<FieldEdit>())
            )
            guard migrated == counts else {
                throw DaylogError.migrationCountMismatch(expected: counts.summary, actual: migrated.summary)
            }
        }

        for routine in try context.fetch(FetchDescriptor<RoutineItem>()) where routine.updatedAt == nil {
            routine.updatedAt = routine.createdAt
        }
        for revision in try context.fetch(FetchDescriptor<RoutineRevision>()) where revision.syncID == nil {
            revision.syncID = UUID()
        }
        for record in try context.fetch(FetchDescriptor<DayRecord>()) where record.syncID == nil {
            record.syncID = UUID()
        }
        for check in try context.fetch(FetchDescriptor<DayCheck>()) where check.syncID == nil {
            check.syncID = UUID()
        }
        for settings in try context.fetch(FetchDescriptor<AppSettings>()) where settings.syncID == nil {
            settings.syncID = UUID()
        }
        // 그룹 없이 만든 항목이 있으면 "기본 루틴" 그룹을 만든다. 항목과 과거 기록은 고쳐 쓰지 않는다
        // (그룹 정보가 없는 항목·기록은 읽을 때 "기본 루틴"으로 본다).
        try MainActor.assumeIsolated {
            _ = try RoutineService(context: context).ensureDefaultGroup()
        }
        try context.saveIfNeeded()
    }
}

/// 저장소 옆에 두는 작은 정보 파일(<이름>.store.info.json). 마지막으로 연 형식과 iCloud 연결 여부를 적는다.
struct StoreInfo: Codable, Equatable {
    var schemaVersion: Int
    var cloudKitContainerID: String?
    /// 이 저장소 파일(= 이 기기)의 식별자. 기기별 편집 기록을 구분하는 데 쓴다. 동기화되지 않는다.
    var deviceID: String?

    private static func url(for storeURL: URL) -> URL {
        URL(fileURLWithPath: storeURL.path + ".info.json")
    }

    static func read(for storeURL: URL) -> StoreInfo? {
        guard let data = try? Data(contentsOf: url(for: storeURL)) else { return nil }
        return try? JSONDecoder().decode(StoreInfo.self, from: data)
    }

    func write(for storeURL: URL) throws {
        try JSONEncoder().encode(self).write(to: Self.url(for: storeURL), options: .atomic)
    }
}

struct StoreOpenError: LocalizedError {
    let underlying: Error
    let backupDirectory: URL?

    var errorDescription: String? {
        var message = underlying.localizedDescription
        if let backupDirectory {
            message += "\n\n열기 전에 만든 백업: \(backupDirectory.path)"
        }
        return message
    }
}

extension ModelContext {
    func saveIfNeeded() throws {
        guard hasChanges else { return }
        try save()
    }
}
