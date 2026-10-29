import Foundation
import Testing
@testable import Daylog

/// 잠금 화면 위젯·카드가 건너뛴 루틴을 "안 함"으로 세지 않는지(2026-10-30).
/// 달성률은 앱과 같이 완료/전체 그대로이고, 남은 개수에서만 건너뛴 것을 뺀다.
struct WidgetSkipTests {
    private func item(_ title: String, done: Bool = false, skipped: Bool = false) -> WidgetItem {
        WidgetItem(routineID: UUID(), title: title, timeLabel: "", isDone: done, isSkipped: skipped ? true : nil)
    }

    private func day(_ items: [WidgetItem]) -> WidgetDay {
        WidgetDay(dateKey: "2026-10-30", groups: [WidgetGroup(id: UUID(), title: "아침", colorKey: "mint", items: items)])
    }

    @Test func skippedRoutinesAreNotLeftButKeepTheRate() {
        let today = day([item("물", done: true), item("스트레칭", skipped: true), item("독서")])
        #expect(today.done == 1)
        #expect(today.skipped == 1)
        #expect(today.remaining == 1)
        #expect(today.percent == 33)
        #expect(today.nextToShow(nowMinutes: 600)?.title == "독서")
    }

    @Test func skippingTheLastRoutineLeavesNothing() {
        let today = day([item("물", done: true), item("스트레칭", skipped: true)])
        #expect(today.remaining == 0)
        #expect(today.skipped == 1)
        #expect(today.nextToShow(nowMinutes: 600) == nil)
    }

    @Test func aCompletedRoutineIsNeverCountedAsSkipped() {
        let today = day([item("물", done: true, skipped: true)])
        #expect(today.skipped == 0)
        #expect(today.done == 1)
    }
}
