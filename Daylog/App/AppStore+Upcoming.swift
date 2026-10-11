import Foundation

/// 오늘과 앞으로 며칠의 예정 루틴. 알림 예약과 위젯이 함께 쓴다.
struct PlannedDay: Equatable {
    let day: Day
    let sections: [CheckSection]
}

extension AppStore {
    /// 오늘은 저장된 체크(완료 여부 포함), 내일부터는 지금의 루틴 설정으로 본 예정.
    func upcomingDays(count: Int) -> [PlannedDay] {
        var result = [PlannedDay(day: today, sections: todaySections)]
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
                result.append(PlannedDay(day: day, sections: sections))
            }
        }
        return result
    }

    /// 위젯에서 누른 체크를 저장소에 반영한다. `watermark` 이전의 것은 이미 반영한 것이라 건너뛴다.
    /// 반영한(또는 건너뛴) 것 중 가장 나중 시각을 돌려준다.
    @discardableResult
    func applyWidgetChecks(_ pending: [PendingCheck], after watermark: Date = .distantPast) -> Date {
        var latest = watermark
        var applied = false
        for check in pending.sorted(by: { $0.at < $1.at }) where check.at > watermark {
            latest = max(latest, check.at)
            // 미래 날짜의 기록은 만들지 않는다.
            guard let day = Day(key: check.dateKey), day <= today else { continue }
            perform {
                let edits = FieldEditService(context: context, deviceID: deviceID)
                // 위젯에서 누른 뒤에 (이 기기든 다른 기기든) 더 나중에 정한 값이 있으면 그 값을 따른다.
                if let newest = try edits.latestCheckEdit(dateKey: check.dateKey, routineID: check.routineID),
                   newest > check.at { return }
                let record = try DayRecordService(context: context).fetchOrCreate(day: day, today: today)
                guard let target = record.checkList.first(where: { $0.routineID == check.routineID }),
                      target.isDone != check.isDone else { return }
                try edits.recordCheck(dateKey: record.dateKey, routineID: check.routineID, isDone: check.isDone, now: check.at)
                try DayRecordService(context: context).setDone(target, check.isDone, now: check.at)
                applied = true
            }
        }
        if applied { reloadStats() }
        return latest
    }
}
