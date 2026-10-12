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
/// 명령: group, add(마지막으로 쓴 그룹에), check, uncheck, text:<칸>=<값>, rename:<전>=<후>, time:<루틴>=<HH:mm>, notify:on|off,
///       archive, restore, archiveGroup, threshold,
///       wait:<초>, waitImport:<최대 초>, waitExport:<최대 초>, refresh, dump:<이름>,
///       section:<메뉴>(dashboard, routines, meals, statistics, calendar, settings),
///       counts(개수만 출력), compareBackup:<백업 이름 일부>, verifyBackup:<백업 이름 일부>,
///       purgeLocalStore, quit
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
        case "time":
            // 예정 시간 정하기: time:<루틴>=<HH:mm>. 알림과 위젯 검증에 쓴다.
            if pair.count == 2, let routine = store.routines.first(where: { $0.title == pair[0] }) {
                store.updateRoutine(routine, timeLabel: pair[1])
            }
        case "notify":
            // 루틴 알림 켜기/끄기: notify:on, notify:off. 처음 켜면 시스템이 권한을 묻는다.
            await AppRuntime.shared?.notifications.setEnabled(argument == "on")
            await AppRuntime.shared?.refreshNow()
            log("NOTIFY \(AppRuntime.shared?.notifications.permission.title ?? "-") 예약 \(AppRuntime.shared?.notifications.scheduledCount ?? -1)개")
        case "vacation":
            // 검증용 날짜 범위. 실제 사용자 앱에서는 요청한 경우에만 실행된다.
            let dates = argument.split(separator: ",").map(String.init)
            if dates.count >= 2, let start = Day(key: dates[0]), let end = Day(key: dates[1]) {
                // 날짜 뒤에 루틴 이름을 적으면 그 루틴만 유지하는 휴가가 된다: vacation:<시작>,<끝>,<루틴>,<루틴>
                let kept = Set(dates.dropFirst(2).compactMap { title in store.activeRoutines.first { $0.title == title }?.id })
                let saved = store.saveVacation(start: start, end: end, memo: "검증용 휴가", keptRoutineIDs: kept)
                await AppRuntime.shared?.refreshNow()
                log("VACATION saved=\(saved) today=\(store.stats.today.status) average=\(store.stats.weeklyAverage.map(String.init) ?? "nil")")
            }
        case "vacationOff":
            // 이 스크립트가 만든 검증용 휴가만 해제한다.
            for period in store.vacationPeriods where period.memo == "검증용 휴가" {
                store.removeVacation(period)
            }
            await AppRuntime.shared?.refreshNow()
            log("VACATION removed today=\(store.stats.today.status) average=\(store.stats.weeklyAverage.map(String.init) ?? "nil")")
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
        case "weekStart":
            // 달력의 한 주 시작 요일: weekStart:sunday, weekStart:monday. 이 기기 설정만 바꾼다.
            if let value = WeekStart(rawValue: argument) { DevicePreferences.shared.setWeekStart(value) }
        case "forgetUpdateCheck":
            // Sparkle이 기억한 마지막 확인 시각을 지운다. 다음 실행 때 바로 다시 확인한다(업데이트 시험용).
            UserDefaults.standard.removeObject(forKey: "SULastCheckTime")
        #if os(iOS)
        case "refreshUIConfig":
            // 원격 UI 설정을 지금 받아 적용한다([UI 설정 새로고침]과 같다).
            await MobileUIConfigStore.shared.refreshNow()
            logUIConfig()
        case "activateUIConfig":
            // 앱을 열었을 때와 같은 확인(받은 설정은 다음 실행 때 적용된다).
            await MobileUIConfigStore.shared.activate()
            logUIConfig()
        case "forgetUIConfigCheck":
            // 마지막 확인 시각을 잊는다(다음 activate가 1시간 간격과 상관없이 확인한다).
            MobileUIConfigStore.shared.forgetLastCheckForTesting()
        case "dumpUIConfig":
            logUIConfig()
        #endif
        case "restoreDashboard":
            // 대시보드를 기본 배치로 되돌린다(이후 기본 배치를 따른다).
            DevicePreferences.shared.restoreDashboard()
        case "resetNotificationGuide":
            // 알림 안내를 아직 안 본 상태로 되돌린다(다음 실행 때 규칙대로 다시 판단한다).
            UserDefaults.standard.removeObject(forKey: DevicePreferences.notificationGuideKey)
        case "onboardingDone":
            // 시작 안내를 본 것으로 한다. 안내 시트가 떠 있으면 화면 검증과 정상 종료가 막힌다.
            DevicePreferences.shared.completeOnboarding()
        case "showCard", "hideCard":
            // 대시보드 카드 보이기/숨기기: showCard:summary, hideCard:summary. 이 기기 설정만 바꾼다.
            if let card = DashboardCard(rawValue: argument) {
                DevicePreferences.shared.setVisible(name == "showCard", card: card)
            }
        case "transfer":
            // 가져오기 시트를 열고 파일 미리보기를 만든다: transfer:<CSV·JSON 경로>. 파일 선택 창은 배경에서 조작할 수 없어서 둔다.
            pendingTransferFile = URL(fileURLWithPath: argument)
            presentsTransfer = true
            store.section = .settings
        case "section":
            // 화면 전환: section:routines 처럼 메뉴 이름(dashboard, routines, meals, statistics, calendar, settings).
            if let section = AppStore.Section.allCases.first(where: { "\($0)" == argument }) {
                store.section = section
            }
        case "dump":
            store.flush()
            dump(label: argument, store: store, sync: sync, container: container)
        case "counts":
            counts(container: container)
            // 동기화 상태도 내용 없이 한 줄로 남긴다.
            log("COUNTS sync 계정 \(sync.account.title), 컨테이너 \(sync.containerIdentifier ?? "(로컬 전용)"), "
                + "가져오기 \(sync.lastImportAt.map { "\($0)" } ?? "-"), 보내기 \(sync.lastExportAt.map { "\($0)" } ?? "-"), "
                + "오류 \(sync.lastErrorMessage ?? "없음"), 앱 오류 \(store.errorMessage ?? "없음")")
        case "verifyBackup":
            store.flush()
            DebugBackup.verify(labelled: argument, live: container.mainContext)
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

    #if os(iOS)
    /// 원격 UI 설정의 상태 한 줄: 적용된 버전, 대기 중인 버전, 마지막 결과, 지금의 카드 배치.
    private static func logUIConfig() {
        let config = MobileUIConfigStore.shared
        let preferences = DevicePreferences.shared
        log("UICONFIG applied=\(config.settings.configVersion) pending=\(config.pending.map { String($0.configVersion) } ?? "-") "
            + "outcome=\(config.lastOutcome.map { "\($0)" } ?? "-") spacing=\(config.settings.cardSpacing) padding=\(config.settings.cardPadding) "
            + "style=\(config.settings.cardStyle.rawValue) accent=\(config.settings.accent.rawValue) greeting=\(config.settings.string(.dashboardGreeting)) "
            + "customized=\(preferences.isLayoutCustomized) visible=\(preferences.visibleCards.map(\.rawValue).joined(separator: ","))")
    }
    #endif

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

    /// `transfer:` 명령이 남긴 상태. 설정 화면의 가져오기 단추와 시트가 읽는다.
    static var pendingTransferFile: URL?
    static var presentsTransfer = false

    private static func log(_ message: String) {
        print("DAYLOG_SCRIPT \(message)")
        fflush(stdout)
    }
}
#endif
