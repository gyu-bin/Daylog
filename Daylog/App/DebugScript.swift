#if DEBUG
import Foundation
import SwiftData

/// 동기화 검증용 스크립트 실행기. Debug 빌드에만 들어가고, 실행 인자를 주지 않으면 아무 일도 하지 않는다.
///
/// 한 Mac에서 저장소 파일을 둘로 나눠 두 기기처럼 띄우고, 각 인스턴스가 정해진 동작을 한 뒤 상태를
/// 표준 출력에 찍게 한다. 팀 서명된 앱의 저장소는 다른 프로세스가 읽을 수 없어서 앱이 직접 출력해야 한다.
///
///     open -n -W --stdout /tmp/a.log Daylog.app --args -DaylogStoreName verify \
///         -DaylogDebugScript "add:운동;check:운동;text:breakfast=토스트;dump:A;quit"
///
/// 명령: group, add(마지막으로 쓴 그룹에), check, uncheck, text:<칸>=<값>, rename:<전>=<후>, archive, restore, archiveGroup, threshold,
///       wait:<초>, waitImport:<최대 초>, waitExport:<최대 초>, refresh, dump:<이름>,
///       counts(개수만 출력), compareBackup:<백업 이름 일부>, purgeLocalStore, quit
///
/// 실제 기록이 iCloud에 있으므로, iCloud의 데이터를 지우는 명령은 두지 않는다.
/// 검증용 저장소는 항상 로컬 전용으로 열린다(`RuntimeEnvironment.cloudKitContainerID`).
@MainActor
enum DebugScript {
    static func runIfRequested(store: AppStore, sync: CloudSyncMonitor, container: ModelContainer) {
        guard let script = UserDefaults.standard.string(forKey: "DaylogDebugScript"), !script.isEmpty else { return }
        Task {
            // 창이 뜨고 저장소 변경 알림 구독이 시작된 뒤에 실행한다.
            try? await Task.sleep(for: .seconds(1))
            for command in script.split(separator: ";").map(String.init) {
                await run(command, store: store, sync: sync, container: container)
            }
        }
    }

    private static func run(_ command: String, store: AppStore, sync: CloudSyncMonitor, container: ModelContainer) async {
        let parts = command.split(separator: ":", maxSplits: 1).map(String.init)
        let name = parts.first ?? ""
        let argument = parts.count > 1 ? parts[1] : ""
        let pair = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)

        switch name {
        case "group":
            store.addGroup(title: argument)
        case "add":
            store.addRoutine(title: argument, in: store.quickAddGroup)
        case "check", "uncheck":
            if let check = store.checks.first(where: { $0.title == argument }) {
                store.setDone(routineID: check.routineID, name == "check")
            } else {
                log("NOT_FOUND check \(argument)")
            }
        case "text":
            if pair.count == 2, let field = DayTextField(rawValue: pair[0]) {
                store.setText(pair[1], at: field.keyPath)
                store.flush()
            }
        case "rename":
            if pair.count == 2, let routine = store.routines.first(where: { $0.title == pair[0] }) {
                store.updateRoutine(routine, title: pair[1])
            }
        case "archive", "restore":
            if let routine = store.routines.first(where: { $0.title == argument }) {
                store.setArchived(routine, name == "archive")
            }
        case "archiveGroup":
            if let group = store.groups.first(where: { $0.title == argument }) {
                store.setGroupArchived(group, true)
            }
        case "threshold":
            store.setThreshold(Int(argument) ?? store.threshold)
        case "wait":
            try? await Task.sleep(for: .seconds(Double(argument) ?? 1))
        case "waitImport":
            await waitForEvent(named: "import", timeout: Double(argument) ?? 60) { sync.lastImportAt }
        case "waitExport":
            await waitForEvent(named: "export", timeout: Double(argument) ?? 60) { sync.lastExportAt }
        case "refresh":
            store.handleExternalChanges()
        case "dump":
            store.flush()
            dump(label: argument, store: store, sync: sync, container: container)
        case "counts":
            counts(container: container)
            // 동기화 상태도 내용 없이 한 줄로 남긴다.
            log("COUNTS sync 계정 \(sync.account.title), 컨테이너 \(sync.containerIdentifier ?? "(로컬 전용)"), "
                + "가져오기 \(sync.lastImportAt.map { "\($0)" } ?? "-"), 보내기 \(sync.lastExportAt.map { "\($0)" } ?? "-"), "
                + "오류 \(sync.lastErrorMessage ?? "없음"), 앱 오류 \(store.errorMessage ?? "없음")")
        case "compareBackup":
            compareBackup(labelled: argument, store: store)
        case "purgeLocalStore":
            purgeLocalStore()
        case "quit":
            store.flush()
            log("QUIT")
            exit(0)
        default:
            log("UNKNOWN \(command)")
        }
    }

    /// 명령을 시작한 뒤에 끝난 가져오기/보내기 이벤트가 생길 때까지 기다린다.
    private static func waitForEvent(named name: String, timeout: Double, _ latest: () -> Date?) async {
        let started = Date.now
        while Date.now.timeIntervalSince(started) < timeout {
            if let date = latest(), date >= started {
                log("EVENT \(name) after \(String(format: "%.1f", Date.now.timeIntervalSince(started)))s")
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        log("TIMEOUT \(name) \(Int(timeout))s")
    }

    private static func dump(label: String, store: AppStore, sync: CloudSyncMonitor, container: ModelContainer) {
        let context = container.mainContext
        let key = store.today.key
        let physicalRecords = (try? context.fetch(FetchDescriptor<DayRecord>(predicate: #Predicate { $0.dateKey == key }))) ?? []
        var state: [String: Any] = [
            "today": key,
            "routines": store.routines.map { "\($0.title)\($0.isArchived ? " (보관)" : "")" },
            "checks": store.checks.map { "\($0.title)=\($0.isDone ? "완료" : "미완료")" },
            "recordsForToday": physicalRecords.count,
            "physicalChecksForToday": physicalRecords.map { $0.physicalChecks.count }.reduce(0, +),
            "totalRecords": (try? context.fetchCount(FetchDescriptor<DayRecord>())) ?? -1,
            "totalRoutineItems": (try? context.fetchCount(FetchDescriptor<RoutineItem>())) ?? -1,
            "totalRevisions": (try? context.fetchCount(FetchDescriptor<RoutineRevision>())) ?? -1,
            "totalSettings": (try? context.fetchCount(FetchDescriptor<AppSettings>())) ?? -1,
            "stats": "\(store.stats.today.done)/\(store.stats.today.total) avg=\(store.stats.weeklyAverage.map(String.init) ?? "-") "
                + "streak=\(store.stats.currentStreak) longest=\(store.stats.longestStreak) threshold=\(store.threshold)",
            "account": sync.account.title,
            "container": sync.containerIdentifier ?? "(로컬 전용)",
            "lastImport": sync.lastImportAt.map { "\($0)" } ?? "-",
            "lastExport": sync.lastExportAt.map { "\($0)" } ?? "-",
            "syncError": sync.lastErrorMessage ?? "-",
            "notices": store.syncNotices,
            "appError": store.errorMessage ?? "-",
        ]
        for field in DayTextField.allCases {
            state[field.rawValue] = store.text(field.keyPath)
        }
        let edits = (try? context.fetch(FetchDescriptor<FieldEdit>())) ?? []
        state["fieldEdits"] = edits.count
        state["fieldEditList"] = edits
            .sorted { ($0.dateKey, $0.field, $0.deviceID) < ($1.dateKey, $1.field, $1.deviceID) }
            .map { "\($0.dateKey) \($0.field)@\($0.deviceID.prefix(4))=\($0.value) seen=\($0.seen.count)" }
        let data = (try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])) ?? Data()
        log("DUMP \(label) \(String(decoding: data, as: UTF8.self))")
    }

    /// 저장소와 백업에 든 기록의 "개수"만 출력한다. 내용(루틴 이름, 식사 등)은 출력하지 않는다.
    private static func counts(container: ModelContainer) {
        let context = container.mainContext
        func count<T: PersistentModel>(_ type: T.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<T>())) ?? -1
        }
        log("COUNTS now 그룹 \(count(RoutineGroup.self)), 루틴 \(count(RoutineItem.self)), 이력 \(count(RoutineRevision.self)), "
            + "기록 \(count(DayRecord.self)), 체크 \(count(DayCheck.self)), 설정 \(count(AppSettings.self)), 편집 기록 \(count(FieldEdit.self))")

        let name = UserDefaults.standard.string(forKey: "DaylogStoreName") ?? "Daylog"
        guard let url = try? DaylogStore.storeURL(name: name) else { return }
        log("COUNTS info \(StoreInfo.read(for: url).map { "형식 v\($0.schemaVersion), iCloud \($0.cloudKitContainerID ?? "없음")" } ?? "정보 파일 없음")")
        let root = StoreBackup.backupsRoot(for: url)
        let backups = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        if backups.isEmpty { log("COUNTS backup 없음") }
        for backup in backups.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let store = backup.appendingPathComponent(url.lastPathComponent)
            let summary = (try? StoreBackup.counts(at: store).summary) ?? "읽을 수 없음"
            let intact = (try? StoreBackup.verifyIntegrity(at: store)) != nil
            log("COUNTS backup \(backup.lastPathComponent): \(summary), 무결성 \(intact ? "정상" : "확인 실패")")
        }
    }

    /// 이름에 `label`이 들어간 가장 최근 백업과 지금의 저장소를 비교해, 표·열 이름과 개수만 출력한다.
    private static func compareBackup(labelled label: String, store: AppStore) {
        store.flush()
        let name = UserDefaults.standard.string(forKey: "DaylogStoreName") ?? "Daylog"
        guard let url = try? DaylogStore.storeURL(name: name) else { return }
        let root = StoreBackup.backupsRoot(for: url)
        let backups = ((try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.contains(label) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let backup = backups.last else {
            log("COMPARE 백업 없음(\(label))")
            return
        }
        do {
            let reports = try StoreComparison.compare(backup: backup.appendingPathComponent(url.lastPathComponent), live: url)
            log("COMPARE \(backup.lastPathComponent) 와 현재 저장소")
            for report in reports { log("COMPARE \(report.summary)") }
        } catch {
            log("COMPARE 실패 \(error.localizedDescription)")
        }
    }

    /// `-DaylogDebugPurge YES`로 실행하면 저장소를 열지 않고 검증용 저장소 파일만 지운 뒤 끝낸다.
    /// (형식이 달라 열 수 없는 예전 검증용 저장소를 치울 때 쓴다.)
    static func purgeAndExitIfRequested() {
        guard UserDefaults.standard.bool(forKey: "DaylogDebugPurge") else { return }
        purgeLocalStore()
        exit(0)
    }

    /// 검증용 저장소 파일을 지운다. 실제 저장소(Daylog)는 대상이 아니다.
    private static func purgeLocalStore() {
        guard let name = UserDefaults.standard.string(forKey: "DaylogStoreName"), name != "Daylog",
              let url = try? DaylogStore.storeURL(name: name)
        else {
            log("PURGE refused")
            return
        }
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm", ".info.json"] {
            try? fileManager.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
        let backups = StoreBackup.backupsRoot(for: url)
        for entry in (try? fileManager.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)) ?? []
        where entry.lastPathComponent.hasPrefix("\(name)-") {
            try? fileManager.removeItem(at: entry)
        }
        log("PURGE \(name)")
    }

    private static func log(_ message: String) {
        print("DAYLOG_SCRIPT \(message)")
        fflush(stdout)
    }
}
#endif
