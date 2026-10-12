import Foundation

extension WidgetSnapshot {
    /// 앱의 예정 목록을 위젯용 값으로 옮긴다. 달성률과 그룹 순서는 앱과 같은 규칙(`Achievement`, 그룹 순서)을 따른다.
    static func make(days: [PlannedDay], hasRoutines: Bool) -> WidgetSnapshot {
        WidgetSnapshot(
            days: days.prefix(dayCount).map { planned in
                WidgetDay(
                    dateKey: planned.day.key,
                    groups: planned.sections.map { section in
                        WidgetGroup(
                            id: section.group.id, title: section.group.title, colorKey: section.group.colorKey,
                            items: section.checks.map {
                                WidgetItem(
                                    routineID: $0.id, title: $0.title, timeLabel: $0.timeLabel, isDone: $0.isDone,
                                    isSkipped: $0.isSkipped ? true : nil
                                )
                            }
                        )
                    },
                    isVacation: planned.isVacation,
                    // 평소에는 칸을 쓰지 않아 이전 파일과 같은 모양을 유지한다.
                    keepsRoutines: planned.keepsRoutines ? true : nil
                )
            },
            hasRoutines: hasRoutines
        )
    }
}
