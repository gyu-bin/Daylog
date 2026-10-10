import Foundation
import SwiftData
import Testing
@testable import Daylog

/// v1.3.1: 루틴 관리 화면의 동작(빠른 추가, 삭제 확인 문구, 순서 변경, 보관과 삭제의 차이)
@MainActor
struct RoutineManagementTests {
    private func makeStore(_ env: TestEnv, today: Day) -> AppStore {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        return store
    }

    /// ⌘N: 루틴 관리 화면에서는 그 화면에 머물고, 다른 화면에서는 오늘의 대시보드로 간다.
    @Test func quickAddStaysOnRoutineManagement() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        let token = store.quickAddFocusToken

        store.section = .routines
        store.requestQuickAddFocus()
        #expect(store.section == .routines)
        #expect(store.quickAddFocusToken == token + 1)

        store.section = .statistics
        store.requestQuickAddFocus()
        #expect(store.section == .dashboard)
        #expect(store.isViewingToday)
        #expect(store.quickAddFocusToken == token + 2)
    }

    /// 빠른 추가는 마지막으로 쓴 그룹으로 간다. 그 그룹을 삭제하면 남은 첫 그룹으로 돌아간다.
    @Test func quickAddTargetsTheLastUsedGroup() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        #expect(store.quickAddGroup == nil)

        let morning = try #require(store.addGroup(title: "아침"))
        let evening = try #require(store.addGroup(title: "저녁"))
        #expect(store.quickAddGroup?.id == evening.id)

        store.addRoutine(title: "물", in: morning)
        #expect(store.quickAddGroup?.id == morning.id)

        store.deleteGroup(morning)
        #expect(store.quickAddGroup?.id == evening.id)
    }

    /// 삭제 확인 문구는 함께 삭제되는 항목 수와, 지난 기록이 남는다는 점을 알린다.
    @Test func deletionMessages() {
        #expect(RoutineDeletion.groupMessage(itemCount: 3).contains("루틴 3개도 함께 삭제"))
        #expect(RoutineDeletion.groupMessage(itemCount: 3).contains("지난 기록과 통계는 유지"))
        #expect(!RoutineDeletion.groupMessage(itemCount: 0).contains("함께 삭제"))
        #expect(RoutineDeletion.groupMessage(itemCount: 0).contains("지난 기록과 통계는 유지"))
        #expect(RoutineDeletion.itemMessage.contains("되돌릴 수 없"))
        #expect(RoutineDeletion.itemMessage.contains("지난 기록과 통계는 유지"))
    }

    /// 보관은 복원할 수 있고 보관함에 보인다. 삭제는 목록과 보관함 어디에도 보이지 않는다.
    @Test func archiveIsReversibleButDeleteIsNot() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침"))
        store.addRoutine(title: "물", in: group)
        store.addRoutine(title: "스트레칭", in: group)
        let water = try #require(store.routines.first { $0.title == "물" })
        let stretch = try #require(store.routines.first { $0.title == "스트레칭" })

        store.setArchived(water, true)
        #expect(store.archivedRoutines(inGroup: group.id).map(\.title) == ["물"])
        store.setArchived(water, false)
        #expect(store.activeRoutines(inGroup: group.id).map(\.title).sorted() == ["물", "스트레칭"])

        store.deleteRoutine(stretch)
        #expect(store.activeRoutines(inGroup: group.id).map(\.title) == ["물"])
        #expect(store.archivedRoutines(inGroup: group.id).isEmpty)
        // 레코드는 지우지 않고 삭제 시각만 남긴다.
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineItem>()) == 2)
    }

    /// 메뉴의 위/아래 이동과 "다른 그룹으로 이동".
    @Test func menuMovesReorderAndRegroup() throws {
        let env = try TestEnv()
        let store = makeStore(env, today: monday)
        let morning = try #require(store.addGroup(title: "아침"))
        let evening = try #require(store.addGroup(title: "저녁"))
        for title in ["가", "나", "다"] { store.addRoutine(title: title, in: morning) }
        let last = try #require(store.routines.first { $0.title == "다" })

        store.moveActiveRoutine(last, by: -1)
        #expect(store.activeRoutines(inGroup: morning.id).map(\.title) == ["가", "다", "나"])
        store.moveActiveRoutine(last, by: -5)
        #expect(store.activeRoutines(inGroup: morning.id).map(\.title) == ["가", "다", "나"])

        store.moveRoutine(last, to: evening)
        #expect(store.activeRoutines(inGroup: morning.id).map(\.title) == ["가", "나"])
        #expect(store.activeRoutines(inGroup: evening.id).map(\.title) == ["다"])

        store.moveGroup(evening, by: -1)
        #expect(store.activeGroups.map(\.title) == ["저녁", "아침"])
    }

    /// 기간 선택 버튼의 이름과, 식사 종류별 표시가 서로 겹치지 않는다.
    @Test func periodTitlesAndMealKinds() {
        #expect(StatsPeriod.allCases.map(\.title) == ["7일", "30일", "90일", "전체"])
        #expect(MealPeriod.allCases.map(\.shortTitle) == ["7일", "30일", "전체"])
        #expect(MealKind.allCases.map(\.title) == ["아침", "점심", "저녁", "간식"])
        #expect(Set(MealKind.allCases.map(\.symbol)).count == 4)
        #expect(MealKind.allCases.map(\.field) == [.breakfast, .lunch, .dinner, .snack])
    }
}
