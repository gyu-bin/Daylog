import Foundation

/// 오늘과 앞으로 며칠의 예정 루틴. 알림 예약과 위젯이 함께 쓴다.
struct PlannedDay: Equatable {
    let day: Day
    let sections: [CheckSection]
    var isVacation: Bool = false
    /// 휴가이지만 고른 루틴은 이어 가는 날. `sections`에는 그 루틴만 들어 있다.
    var keepsRoutines: Bool = false
}

extension AppStore {
    /// 오늘은 저장된 체크(완료 여부 포함), 내일부터는 지금의 루틴 설정으로 본 예정.
    func upcomingDays(count: Int) -> [PlannedDay] {
        let todayPolicy = routinePolicy(on: today)
        // `todaySections`는 이미 오늘의 정책대로 걸러져 있다.
        var result = [PlannedDay(
            day: today, sections: todaySections, isVacation: todayPolicy.isVacation, keepsRoutines: todayPolicy.keepsRoutines
        )]
        perform {
            let resolver = try ScheduleResolver(context: context)
            for offset in 1..<max(count, 1) {
                let day = today.adding(days: offset)
                var sections: [CheckSection] = []
                for snapshot in resolver.scheduled(on: day) {
                    let value = CheckValue(
                        id: snapshot.routineID, title: snapshot.title, timeLabel: snapshot.timeLabel,
                        note: snapshot.note, isDone: false
                    )
                    if let index = sections.firstIndex(where: { $0.group.id == snapshot.group.id }) {
                        sections[index].checks.append(value)
                    } else {
                        sections.append(CheckSection(group: snapshot.group, checks: [value]))
                    }
                }
                let policy = routinePolicy(on: day)
                result.append(PlannedDay(
                    day: day, sections: policy.visible(sections), isVacation: policy.isVacation, keepsRoutines: policy.keepsRoutines
                ))
            }
        }
        return result
    }

    /// Requests run on the app's main actor and the existing store; the extension never opens SwiftData.
    /// Persist the user's current drafts before starting a transaction that can be rolled back independently.
    func applyWidgetCheck(_ check: PendingCheck, save: (() throws -> Void)? = nil) throws {
        guard let day = Day(key: check.dateKey), day <= today else { return }
        try recordPendingEdits()
        try context.save()
        do {
            let edits = FieldEditService(context: context, deviceID: deviceID)
            if let newest = try edits.latestCheckEdit(dateKey: check.dateKey, routineID: check.routineID),
               newest > check.at { return }
            let service = DayRecordService(context: context)
            let record = try service.fetchOrCreate(day: day, today: today)
            guard let target = record.checkList.first(where: { $0.routineID == check.routineID }) else { return }
            // Even an unchanged target is a decision: a later cancellation must supersede an earlier completion.
            try edits.recordCheck(dateKey: record.dateKey, routineID: check.routineID, isDone: check.isDone, now: check.at)
            // The generic editor coalesces equal values. Widget targets still carry a newer decision time,
            // so delayed older requests must not undo an explicit no-op cancellation.
            for entry in try edits.entries(dateKey: record.dateKey, fieldName: CheckEdit.fieldName(check.routineID))
                where entry.deviceID == deviceID && entry.editedAt < check.at {
                entry.editedAt = check.at
            }
            target.isDone = check.isDone
            record.activityAt = check.at
            if let save { try save() } else { try context.save() }
        } catch {
            context.rollback()
            refreshChecks()
            throw error
        }
    }

    /// Compatibility batch entry point. Runtime acknowledges individual durable requests instead of a global watermark.
    @discardableResult
    func applyWidgetChecks(_ pending: [PendingCheck], after watermark: Date = .distantPast) -> Date {
        var latest = watermark
        for check in pending.sorted(by: { $0.at < $1.at }) where check.at > watermark {
            guard perform({ try applyWidgetCheck(check) }) else { break }
            latest = max(latest, check.at)
        }
        reloadStats()
        return latest
    }
}
