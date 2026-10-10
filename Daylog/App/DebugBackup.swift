#if DEBUG
import Foundation
import SwiftData

/// 수동 백업과 복원 검증(Debug 빌드 전용). 기록의 내용은 출력하지 않고 개수만 알려 준다.
///
///     open -n -W --stdout <로그> Daylog.app --args -DaylogDebugBackup keep-pre-production \
///         -DaylogDebugScript "verifyBackup:keep-pre-production;quit"
@MainActor
enum DebugBackup {
    /// 저장소에 든 것의 개수. 복원한 사본과 지금 저장소가 같은지 비교한다.
    struct Summary: Equatable {
        var groups = 0, routines = 0, removedRoutines = 0, revisions = 0
        var records = 0, checks = 0, doneChecks = 0, mealDays = 0
        var settings = 0, thresholds: [Int] = [], fieldEdits = 0

        init(_ context: ModelContext) throws {
            groups = try context.fetchCount(FetchDescriptor<RoutineGroup>())
            let items = try context.fetch(FetchDescriptor<RoutineItem>())
            routines = items.count
            removedRoutines = items.filter(\.isRemoved).count
            revisions = try context.fetchCount(FetchDescriptor<RoutineRevision>())
            let days = try context.fetch(FetchDescriptor<DayRecord>())
            records = days.count
            mealDays = days.filter { !($0.breakfast + $0.lunch + $0.dinner + $0.snack + $0.mealMemo).isEmpty }.count
            let allChecks = try context.fetch(FetchDescriptor<DayCheck>())
            checks = allChecks.count
            doneChecks = allChecks.filter(\.isDone).count
            let allSettings = try context.fetch(FetchDescriptor<AppSettings>())
            settings = allSettings.count
            thresholds = allSettings.map(\.achieveThreshold).sorted()
            fieldEdits = try context.fetchCount(FetchDescriptor<FieldEdit>())
        }

        var text: String {
            "그룹 \(groups), 루틴 \(routines)(삭제 \(removedRoutines)), 이력 \(revisions), 기록 \(records), "
                + "체크 \(checks)(완료 \(doneChecks)), 식사를 적은 날 \(mealDays), 설정 \(settings), 편집 기록 \(fieldEdits)"
        }
    }

    private static var storeURL: URL? {
        try? DaylogStore.storeURL(name: UserDefaults.standard.string(forKey: "DaylogStoreName") ?? "Daylog")
    }

    /// `-DaylogDebugBackup <이름>`: 저장소를 열기 전에(아무도 파일에 쓰지 않을 때) 백업을 만든다.
    static func createIfRequested() {
        guard let label = UserDefaults.standard.string(forKey: "DaylogDebugBackup"), !label.isEmpty,
              let url = storeURL, FileManager.default.fileExists(atPath: url.path)
        else { return }
        do {
            let backup = try StoreBackup.create(for: url, label: label)
            let files = (try? FileManager.default.contentsOfDirectory(atPath: backup.directory.path))?.sorted() ?? []
            log("BACKUP created \(backup.directory.lastPathComponent): \(backup.counts.summary), 무결성 정상, 파일 \(files.count)개")
        } catch {
            log("BACKUP failed \(error.localizedDescription)")
        }
    }

    /// 백업을 임시 위치에 복원해 실제로 열리는지, 지금 저장소와 같은지 확인한다. 지금 저장소는 건드리지 않는다.
    static func verify(labelled label: String, live context: ModelContext) {
        guard let url = storeURL else { return }
        let fileManager = FileManager.default
        let root = StoreBackup.backupsRoot(for: url)
        let backups = ((try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.contains(label) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let backup = backups.last else {
            log("VERIFY 백업 없음(\(label))")
            return
        }
        let scratch = url.deletingLastPathComponent().appendingPathComponent("RestoreCheck-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: scratch) }
        do {
            try context.saveIfNeeded()
            try fileManager.createDirectory(at: scratch, withIntermediateDirectories: true)
            let restored = scratch.appendingPathComponent(url.lastPathComponent)
            try StoreBackup.restore(from: backup, storeFileName: url.lastPathComponent, to: restored)
            try StoreBackup.verifyIntegrity(at: restored)
            log("VERIFY \(backup.lastPathComponent) 복원본: 무결성 정상, \(try StoreBackup.counts(at: restored).summary), "
                + "기기 정보 \(StoreInfo.read(for: restored) == StoreInfo.read(for: url) ? "일치" : "불일치")")

            // 행·열 단위 비교: 복원본과 지금 저장소의 모든 값이 같은가.
            let reports = try StoreComparison.compare(backup: restored, live: url)
            let differing = reports.filter { $0.missingInLive + $0.addedInLive + $0.changedRows > 0 }
            log("VERIFY 표 \(reports.count)개 비교: 값이 다른 표 \(differing.count)개")
            for report in differing { log("VERIFY 차이 \(report.summary)") }

            // 앱이 쓰는 방식 그대로 복원본을 열어 본다(로컬 전용).
            let liveSummary = try Summary(context)
            let restoredSummary = try Summary(ModelContext(try DaylogStore.makeContainer(.file(restored))))
            log("VERIFY 지금 저장소: \(liveSummary.text)")
            log("VERIFY 복원본을 앱으로 열기: \(restoredSummary.text)")
            log("VERIFY 결과 \(liveSummary == restoredSummary && differing.isEmpty ? "복원 가능, 지금 저장소와 일치" : "차이 있음")")
        } catch {
            log("VERIFY 실패 \(error.localizedDescription)")
        }
    }

    private static func log(_ message: String) {
        print("DAYLOG_SCRIPT \(message)")
        fflush(stdout)
    }
}
#endif
