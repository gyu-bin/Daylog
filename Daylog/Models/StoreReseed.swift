import Foundation
import SwiftData

/// 저장소의 기록을 동기화 이력이 없는 새 저장소 파일로 옮긴다.
///
/// 저장소에는 "이 기록은 이미 iCloud로 보냈다"는 이력이 함께 들어 있다. 그 이력은 한 CloudKit 환경(Development 또는
/// Production)에 대한 것이라, 다른 환경의 앱으로 같은 저장소를 열면 기존 기록은 "이미 보낸 것"으로 남아 새 환경에
/// 올라가지 않는다(2026-10-10 Mac mini에서 확인: Production에 연결된 뒤 보내기 요청이 한 건도 없었다).
/// 같은 기록을 이력 없는 새 파일로 옮기면, iCloud에 처음 연결하는 저장소처럼 모든 기록을 다시 보낸다.
///
/// 기록의 식별자(id, syncID)와 값은 그대로 옮긴다. 옮긴 뒤 실제 열을 하나하나 비교해 같을 때에만 파일을 바꾼다.
enum StoreReseed {
    /// 자동 정리되지 않는 백업을 만든 뒤 저장소를 다시 만든다. 다시 만들다 실패하면 그 백업으로 되돌리고 오류를 던진다.
    /// 돌려주는 백업은, 그 뒤의 단계(iCloud 연결 등)가 실패했을 때 되돌리는 데 쓴다.
    static func backUpAndRebuild(at url: URL) throws -> StoreBackup.Backup {
        let backup = try StoreBackup.create(for: url, label: "keep-before-reupload")
        do {
            try rebuild(at: url)
        } catch {
            try? StoreBackup.restore(backup, to: url)
            throw error
        }
        return backup
    }

    /// `url`의 저장소를 다시 만든다. 호출하기 전에 백업을 만들어 둘 것. 비교가 끝나기 전에는 원래 파일을 건드리지 않는다.
    static func rebuild(at url: URL) throws {
        let fileManager = FileManager.default
        let info = StoreInfo.read(for: url)
        let scratch = url.deletingLastPathComponent().appendingPathComponent("Reseed-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: scratch) }
        let fresh = scratch.appendingPathComponent(url.lastPathComponent)

        try copyRecords(from: url, to: fresh)

        let differing = StoreContent.differingTables(try StoreContent.rows(at: url), try StoreContent.rows(at: fresh))
        guard differing.isEmpty else {
            throw DaylogError.backupVerificationFailed("새 저장소의 내용이 원본과 달라 바꾸지 않았어요: \(differing.joined(separator: ", "))")
        }

        try StoreBackup.restore(from: scratch, storeFileName: url.lastPathComponent, to: url)
        // 기기 식별자가 든 정보 파일은 그대로 이어 쓴다.
        try info?.write(for: url)
    }

    /// 두 저장소를 iCloud 없이 열어 모든 기록을 옮긴다. 함수가 끝나면 두 저장소가 닫힌다.
    private static func copyRecords(from sourceURL: URL, to targetURL: URL) throws {
        let source = ModelContext(try DaylogStore.container(at: sourceURL, cloudKitContainerID: nil))
        let target = ModelContext(try DaylogStore.container(at: targetURL, cloudKitContainerID: nil))
        target.autosaveEnabled = false

        for old in try source.fetch(FetchDescriptor<RoutineGroup>()) {
            let new = RoutineGroup(
                id: old.id, title: old.title, colorKey: old.colorKey, order: old.order,
                isArchived: old.isArchived, createdAt: old.createdAt
            )
            new.updatedAt = old.updatedAt
            new.deletedAt = old.deletedAt
            target.insert(new)
        }

        for old in try source.fetch(FetchDescriptor<RoutineItem>()) {
            let new = RoutineItem(id: old.id, title: old.title, order: old.order)
            new.title = old.title
            new.note = old.note
            new.timeLabel = old.timeLabel
            new.weekdayMask = old.weekdayMask
            new.isArchived = old.isArchived
            new.createdAt = old.createdAt
            new.updatedAt = old.updatedAt
            new.groupID = old.groupID
            new.deletedAt = old.deletedAt
            target.insert(new)
        }

        let placeholder = RoutineState(
            title: "", timeLabel: "", note: "", weekdayMask: 0, isArchived: false, order: 0, group: .legacy
        )
        for old in try source.fetch(FetchDescriptor<RoutineRevision>()) {
            let new = RoutineRevision(routineID: old.routineID, state: placeholder, effectiveFrom: Day.today())
            new.effectiveFromKey = old.effectiveFromKey
            new.title = old.title
            new.timeLabel = old.timeLabel
            new.note = old.note
            new.weekdayMask = old.weekdayMask
            new.isArchived = old.isArchived
            new.order = old.order
            new.updatedAt = old.updatedAt
            new.syncID = old.syncID
            new.groupID = old.groupID
            new.groupTitle = old.groupTitle
            new.groupColorKey = old.groupColorKey
            new.groupOrder = old.groupOrder
            target.insert(new)
        }

        func copy(_ old: DayCheck) -> DayCheck {
            let new = DayCheck(routineID: old.routineID, state: placeholder, isDone: old.isDone)
            new.title = old.title
            new.timeLabel = old.timeLabel
            new.note = old.note
            new.order = old.order
            new.isHidden = old.isHidden
            new.syncID = old.syncID
            new.groupID = old.groupID
            new.groupTitle = old.groupTitle
            new.groupColorKey = old.groupColorKey
            new.groupOrder = old.groupOrder
            return new
        }

        for old in try source.fetch(FetchDescriptor<DayRecord>()) {
            let new = DayRecord(day: Day.today())
            new.dateKey = old.dateKey
            new.date = old.date
            new.breakfast = old.breakfast
            new.lunch = old.lunch
            new.dinner = old.dinner
            new.snack = old.snack
            new.mealMemo = old.mealMemo
            new.tomorrowTask = old.tomorrowTask
            new.activityAt = old.activityAt
            new.createdAt = old.createdAt
            new.syncID = old.syncID
            new.mergeState = old.mergeState
            target.insert(new)
            for check in old.physicalChecks {
                new.attach(copy(check))
            }
        }
        // 어느 기록에도 붙어 있지 않은 체크(있다면)도 빠뜨리지 않는다.
        for old in try source.fetch(FetchDescriptor<DayCheck>()) where old.record == nil {
            target.insert(copy(old))
        }

        for old in try source.fetch(FetchDescriptor<FieldEdit>()) {
            let new = FieldEdit(dateKey: old.dateKey, field: old.field, deviceID: old.deviceID)
            new.value = old.value
            new.editedAt = old.editedAt
            new.seenState = old.seenState
            new.syncID = old.syncID
            target.insert(new)
        }

        for old in try source.fetch(FetchDescriptor<AppSettings>()) {
            let new = AppSettings(achieveThreshold: old.achieveThreshold, firstRoutineDate: old.firstRoutineDate)
            new.singletonKey = old.singletonKey
            new.updatedAt = old.updatedAt
            new.syncID = old.syncID
            target.insert(new)
        }

        try target.save()
    }
}

/// 저장소를 열 때 CloudKit 환경을 어떻게 다룰지 정한다. 파일을 건드리지 않는 순수 계산.
enum CloudEnvironmentPlan: Equatable {
    /// 지금처럼 연다.
    case proceed
    /// 기록을 이력 없는 새 저장소로 옮긴 뒤 연다(모든 기록을 지금 환경에 다시 보낸다).
    case reseed
    /// 다른 환경과 동기화하던 저장소다. 섞이지 않게 열지 않는다.
    case refuse(previous: String, current: String)

    static func decide(storeExists: Bool, info: StoreInfo?, cloudKitContainerID: String?, environment: String?, reuploadAll: Bool) -> Self {
        // iCloud를 쓰지 않거나, 이 저장소가 같은 컨테이너에 연결된 적이 없으면 따질 것이 없다(처음 연결하면 전부 올라간다).
        guard storeExists, let cloudKitContainerID, let environment, info?.cloudKitContainerID == cloudKitContainerID else {
            return .proceed
        }
        if reuploadAll {
            // 같은 환경에 이미 한 번 다시 올렸으면 또 하지 않는다(같은 기록이 두 번 올라가지 않게).
            return info?.reseedEnvironment == environment ? .proceed : .reseed
        }
        if let previous = info?.cloudKitEnvironment, previous != environment {
            return .refuse(previous: previous, current: environment)
        }
        return .proceed
    }
}
