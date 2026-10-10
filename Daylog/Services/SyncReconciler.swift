import Foundation
import SwiftData

/// 두 값을 잃지 않고 하나로 합치는 규칙.
enum TextMerge {
    /// 한쪽이 비었거나 다른 쪽에 이미 들어 있으면 그대로, 서로 다른 내용이면 둘 다 남긴다.
    /// `isConflict`는 서로 다른 내용을 이어 붙였다는 뜻이다.
    static func merge(_ primary: String, _ other: String, separator: String) -> (value: String, isConflict: Bool) {
        let trimmedPrimary = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOther = other.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOther.isEmpty || trimmedPrimary == trimmedOther || primary.contains(trimmedOther) {
            return (primary, false)
        }
        if trimmedPrimary.isEmpty || other.contains(trimmedPrimary) {
            return (other, false)
        }
        return (primary + separator + other, true)
    }
}

/// 대표 기록이 다른 기록·중복 체크에서 이미 가져온 내용.
///
/// 병합은 "지난번에 가져온 뒤로 달라진 것"만 다시 가져온다. 그래서 여러 번 실행해도 결과가 같고,
/// 가져온 뒤 사용자가 대표 기록에서 고치거나 지운 내용이 되살아나지 않는다.
struct MergeLedger: Codable, Equatable {
    /// "<기록 식별자>|<칸 이름>" → 가져온 값의 해시
    var texts: [String: String] = [:]
    /// "<체크 식별자>" → 가져온 완료 여부
    var checks: [String: Bool] = [:]

    /// 실행할 때마다 달라지지 않는 해시(FNV-1a). `hashValue`는 프로세스마다 달라 저장할 수 없다.
    static func hash(_ text: String) -> String {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x0000_0100_0000_01b3
        }
        return String(value, radix: 16)
    }
}

extension DayRecord {
    var mergeLedger: MergeLedger {
        get {
            guard let mergeState, let ledger = try? JSONDecoder().decode(MergeLedger.self, from: mergeState) else {
                return MergeLedger()
            }
            return ledger
        }
        set {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            mergeState = try? encoder.encode(newValue)
        }
    }
}

/// 동기화로 생긴 중복을 정리한다(명세의 DuplicateRecordResolver).
///
/// 원칙
/// - 아무것도 지우지 않는다. 다른 기기가 아직 그 기록에 쓰고 있을 수 있고, 지운 것은 되돌릴 수 없다.
/// - 다른 기록은 고치지 않는다. 대표 기록에만 쓴다.
/// - 어느 기기에서 실행해도 같은 대표를 고르고 같은 결과를 만든다.
/// - 여러 번 실행해도 결과가 달라지지 않는다.
@MainActor
struct SyncReconciler {
    struct Report: Equatable {
        /// 저장소에 변경이 있었는가.
        var changed = false
        /// 서로 다른 내용을 함께 보존한 경우의 안내 문구.
        var notices: [String] = []
    }

    /// 중복 체크를 찾으려고 훑는 기간. 그보다 오래된 날짜는 같은 날짜의 기록이 둘 이상일 때만 본다.
    static let recentDays = 90

    let context: ModelContext
    /// 이 기기의 식별자. 기기별 편집 기록에 쓴다.
    let deviceID: String

    private var edits: FieldEditService { FieldEditService(context: context, deviceID: deviceID) }

    @discardableResult
    func reconcile(today: Day) throws -> Report {
        var report = Report()
        try context.saveIfNeeded()
        try mergeSettings()
        try resolveFieldEdits(report: &report)
        try mergeRecords(today: today, report: &report)
        // 그룹 없이 만든 항목이 다른 기기에서 들어왔을 수 있다.
        try RoutineService(context: context).ensureDefaultGroup()
        try RoutineService(context: context).syncTodayRecord(today: today)
        report.changed = context.hasChanges
        try context.saveIfNeeded()
        return report
    }

    // MARK: - 설정

    /// 기준값은 가장 나중에 바꾼 값, 통계 시작일은 가장 이른 날을 대표 설정에 모은다.
    private func mergeSettings() throws {
        let all = try SettingsService(context: context).allSettings()
        guard all.count > 1, let representative = all.first else { return }

        // `all`은 이미 대표 순서라서, 시각이 같으면 앞쪽이 이긴다(기기와 무관하게 같은 결과).
        var latest = representative
        for candidate in all.dropFirst()
        where (candidate.updatedAt ?? .distantPast) > (latest.updatedAt ?? .distantPast) {
            latest = candidate
        }
        if representative.achieveThreshold != latest.achieveThreshold {
            representative.achieveThreshold = latest.achieveThreshold
        }
        if representative.updatedAt != latest.updatedAt {
            representative.updatedAt = latest.updatedAt
        }
        if let earliest = all.compactMap(\.firstRoutineDate).min(), representative.firstRoutineDate != earliest {
            representative.firstRoutineDate = earliest
        }
    }

    // MARK: - 같은 칸의 동시 편집

    /// 기기별 편집 기록으로 각 칸의 값을 정한다.
    /// 두 기기가 서로의 내용을 보지 못한 채 같은 칸을 고쳤다면 두 내용을 모두 남긴다.
    private func resolveFieldEdits(report: inout Report) throws {
        let service = edits
        for group in try service.groups() {
            guard let resolution = FieldEditResolver.resolve(group.entries.map(\.snapshot), separator: group.field.separator),
                  let day = Day(key: group.dateKey),
                  let representative = try DayRecordService(context: context).record(on: day)
            else { continue }

            if resolution.needsMerge {
                // 합친 값을 이 기기의 새 편집으로 남긴다. 모든 편집을 보고 쓴 것이므로 이후에는 이 값 하나만 남는다.
                try service.recordEdit(dateKey: group.dateKey, field: group.field, value: resolution.value)
                if resolution.isConflict {
                    report.notices.append("\(day.shortTitle) \(group.field.label): 두 기기에서 다르게 적은 내용을 함께 남겼어요.")
                }
            }
            if representative[keyPath: group.field.keyPath] != resolution.value {
                representative[keyPath: group.field.keyPath] = resolution.value
            }
        }
    }

    // MARK: - 날짜별 기록

    private func mergeRecords(today: Day, report: inout Report) throws {
        let recentKey = today.adding(days: -Self.recentDays).key
        let groups = Dictionary(grouping: try context.fetch(FetchDescriptor<DayRecord>()), by: \.dateKey)

        for (dateKey, records) in groups {
            let ordered = records.sorted(by: DayRecordService.precedes)
            guard let representative = ordered.first else { continue }
            let others = Array(ordered.dropFirst())
            guard !others.isEmpty || dateKey >= recentKey else { continue }

            var ledger = representative.mergeLedger
            let original = ledger

            for other in others {
                try mergeTexts(from: other, into: representative, ledger: &ledger, report: &report)
                if let activity = other.activityAt, activity > (representative.activityAt ?? .distantPast) {
                    representative.activityAt = activity
                }
                for check in other.physicalChecks.sorted(by: { SyncOrder.precedes($0.syncID, $1.syncID) }) {
                    mergeCheck(check, into: representative, ledger: &ledger)
                }
            }
            mergeDuplicateChecks(in: representative, ledger: &ledger)

            if ledger != original {
                representative.mergeLedger = ledger
            }
        }
    }

    private func mergeTexts(
        from other: DayRecord, into representative: DayRecord, ledger: inout MergeLedger, report: inout Report
    ) throws {
        for field in DayTextField.allCases {
            let incoming = other[keyPath: field.keyPath]
            let ledgerKey = other.syncID.map { "\($0.uuidString)|\(field.rawValue)" }
            let incomingHash = MergeLedger.hash(incoming)
            if let ledgerKey, ledger.texts[ledgerKey] == incomingHash { continue }

            let merged = TextMerge.merge(representative[keyPath: field.keyPath], incoming, separator: field.separator)
            if merged.value != representative[keyPath: field.keyPath] {
                representative[keyPath: field.keyPath] = merged.value
                // 합친 값도 이 기기의 편집으로 남겨야 다음 실행에서 편집 기록이 이 값을 되돌리지 않는다.
                try edits.recordEdit(dateKey: representative.dateKey, field: field, value: merged.value)
                if merged.isConflict {
                    let title = Day(key: representative.dateKey)?.shortTitle ?? representative.dateKey
                    report.notices.append("\(title) \(field.label): 두 기기에서 다르게 적은 내용을 함께 남겼어요.")
                }
            }
            if let ledgerKey {
                ledger.texts[ledgerKey] = incomingHash
            }
        }
    }

    /// 다른 기록의 체크를 대표 기록에 반영한다. 대표 기록에 그 루틴이 없으면 사본을 만든다(원본은 옮기지 않는다).
    private func mergeCheck(_ check: DayCheck, into representative: DayRecord, ledger: inout MergeLedger) {
        let siblings = representative.physicalChecks.filter { $0.routineID == check.routineID }
        guard let target = siblings.min(by: { SyncOrder.precedes($0.syncID, $1.syncID) }) else {
            let copy = DayCheck(
                routineID: check.routineID,
                state: RoutineState(
                    title: check.title, timeLabel: check.timeLabel, note: check.note, weekdayMask: 0,
                    isArchived: false, order: check.order, group: check.group
                ),
                isDone: check.isDone
            )
            copy.isHidden = check.isHidden
            context.insert(copy)
            representative.attach(copy)
            if let id = check.syncID?.uuidString {
                ledger.checks[id] = check.isDone
            }
            return
        }
        absorb(check, into: target, ledger: &ledger)
    }

    /// 한 기록 안에 같은 루틴의 체크가 여럿이면 대표 하나에 완료 여부를 모은다.
    private func mergeDuplicateChecks(in record: DayRecord, ledger: inout MergeLedger) {
        let groups = Dictionary(grouping: record.physicalChecks, by: \.routineID)
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted { SyncOrder.precedes($0.syncID, $1.syncID) }
            guard let target = ordered.first else { continue }
            for duplicate in ordered.dropFirst() {
                absorb(duplicate, into: target, ledger: &ledger)
            }
        }
    }

    /// 처음 보는 체크는 완료 표시만 가져온다(완료를 임의로 해제하지 않는다).
    /// 이미 본 체크가 그 뒤로 바뀌었다면 다른 기기에서 사용자가 바꾼 것이므로 그 값을 따른다.
    private func absorb(_ check: DayCheck, into target: DayCheck, ledger: inout MergeLedger) {
        guard let id = check.syncID?.uuidString else {
            if check.isDone && !target.isDone { target.isDone = true }
            return
        }
        let current = check.isDone
        if let absorbed = ledger.checks[id] {
            guard absorbed != current else { return }
            if target.isDone != current { target.isDone = current }
        } else if current && !target.isDone {
            target.isDone = true
        }
        ledger.checks[id] = current
    }
}
