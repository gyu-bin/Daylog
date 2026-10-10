import Foundation
import SwiftData
import Testing
@testable import Daylog

/// v1.3 (TEST 10): v1.2 저장소 → 그룹이 있는 형식
@MainActor
struct GroupMigrationTests {
    @Test func v2StoreKeepsEverythingAndGainsTheDefaultGroup() throws {
        let (directory, storeURL) = try Fixture.copyOfV2Store()
        defer { try? FileManager.default.removeItem(at: directory) }
        let expected = try Fixture.expectedV2Snapshot()
        let originalBytes = try Data(contentsOf: storeURL)

        let container = try DaylogStore.makeContainer(.file(storeURL))
        let context = container.mainContext

        // 루틴 UUID, 변경 이력, 날짜 키, 체크, 식사, 편집 기록, 설정, 통계가 모두 그대로다.
        let migrated = try FixtureSnapshot.capture(context: context, today: Fixture.today)
        #expect(migrated.routines == expected.routines)
        #expect(migrated.revisions == expected.revisions)
        #expect(migrated.records == expected.records)
        #expect(migrated.fieldEdits == expected.fieldEdits)
        #expect(migrated.stats == expected.stats)
        #expect(migrated == expected)
        #expect(expected.records.count == 19)
        #expect(expected.fieldEdits?.count == 15)

        // 기존 항목은 "기본 루틴" 그룹 하나에 속한다. 항목·체크·이력 레코드는 고쳐 쓰지 않았다.
        let service = RoutineService(context: context)
        let groups = try service.groups()
        #expect(groups.map(\.title) == ["기본 루틴"])
        #expect(groups.first?.id == RoutineGroup.defaultID)
        #expect(try service.routines().allSatisfy { $0.effectiveGroupID == RoutineGroup.defaultID && $0.groupID == nil })
        #expect(try context.fetch(FetchDescriptor<DayCheck>()).allSatisfy { $0.group == .legacy && $0.groupID == nil })
        #expect(try context.fetch(FetchDescriptor<RoutineRevision>()).allSatisfy { $0.group == .legacy })

        let stats = try StatsService(context: context).dashboard(today: Fixture.today)
        #expect(stats.groupRates.count == 1)
        #expect(stats.groupRates.first?.title == "기본 루틴")
        #expect(stats.groupRates.first?.done == stats.routineRates.map(\.done).reduce(0, +))
        #expect(stats.groupRates.first?.scheduled == stats.routineRates.map(\.scheduled).reduce(0, +))

        // 열기 전에 만든 백업은 옮기기 전 상태 그대로다.
        let root = StoreBackup.backupsRoot(for: storeURL)
        let backup = root.appendingPathComponent(try #require(try FileManager.default.contentsOfDirectory(atPath: root.path).first))
        #expect(backup.lastPathComponent.hasPrefix("Daylog-before-v3-"))
        #expect(try Data(contentsOf: backup.appendingPathComponent("Daylog.store")) == originalBytes)
    }

    @Test func reopeningDoesNotDuplicateTheDefaultGroup() throws {
        let (directory, storeURL) = try Fixture.copyOfV2Store()
        defer { try? FileManager.default.removeItem(at: directory) }

        for _ in 0..<3 {
            let store = AppStore(container: try DaylogStore.makeContainer(.file(storeURL)), clock: { Fixture.today })
            store.start()
            store.handleExternalChanges()
            #expect(store.groups.map(\.title) == ["기본 루틴"])
            #expect(store.errorMessage == nil)
        }
        let container = try DaylogStore.makeContainer(.file(storeURL))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<RoutineGroup>()) == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: StoreBackup.backupsRoot(for: storeURL).path).count == 1)
    }

    /// 옮긴 뒤 그룹을 만들고 항목을 옮겨도 과거 기록과 달성률은 그대로다.
    @Test func editingGroupsAfterMigrationKeepsHistory() throws {
        let (directory, storeURL) = try Fixture.copyOfV2Store()
        defer { try? FileManager.default.removeItem(at: directory) }
        let expected = try Fixture.expectedV2Snapshot()

        let container = try DaylogStore.makeContainer(.file(storeURL))
        let store = AppStore(container: container, clock: { Fixture.today })
        store.start()
        let before = store.stats
        let defaultGroup = try #require(store.groups.first)
        let workout = try #require(store.addGroup(title: "운동 루틴", colorKey: "mint"))
        store.updateGroup(defaultGroup, title: "아침 루틴", colorKey: "orange")
        store.moveRoutine(try #require(store.routines.first { $0.title == "운동 (러닝)" }), to: workout)

        #expect(store.checkSections.map(\.group.title) == ["아침 루틴", "운동 루틴"])
        #expect(store.stats.week == before.week)
        #expect(store.stats.trend == before.trend)
        #expect(store.stats.currentStreak == before.currentStreak)
        #expect(store.stats.longestStreak == before.longestStreak)
        #expect(store.stats.routineRates.map(\.percent) == before.routineRates.map(\.percent))

        // 과거 날짜는 여전히 "기본 루틴"으로 보인다.
        store.select(Fixture.today.adding(days: -1))
        #expect(store.checkSections.map(\.group.title) == ["기본 루틴"])
        var snapshot = try FixtureSnapshot.capture(context: container.mainContext, today: Fixture.today)
        let pastRecords = snapshot.records.filter { $0.dateKey != Fixture.today.key }
        #expect(pastRecords == expected.records.filter { $0.dateKey != Fixture.today.key })
        snapshot.fieldEdits = nil
    }

    /// v1.1 저장소도 두 단계를 거쳐 그대로 넘어온다.
    @Test func v1StoreAlsoGainsTheDefaultGroup() throws {
        let (directory, storeURL) = try Fixture.copyOfV1Store()
        defer { try? FileManager.default.removeItem(at: directory) }

        let container = try DaylogStore.makeContainer(.file(storeURL))
        #expect(try RoutineService(context: container.mainContext).groups().map(\.title) == ["기본 루틴"])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<RoutineItem>()) == 5)
    }
}
