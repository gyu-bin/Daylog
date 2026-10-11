import Foundation
import SwiftData
import Testing
@testable import Daylog

@MainActor
struct WidgetReliabilityTests {
    enum Failure: Error { case diskFull }

    private func temporaryBridge() -> WidgetBridge {
        WidgetBridge(directory: FileManager.default.temporaryDirectory.appendingPathComponent("DaylogWidgetJournal-\(UUID())"))
    }

    @Test func pendingNeverCountsAsConfirmedAndCancellationUsesLatestTarget() {
        let id = UUID()
        let original = WidgetDay(dateKey: monday.key, groups: [WidgetGroup(id: UUID(), title: "아침", colorKey: "mint", items: [WidgetItem(routineID: id, title: "물", timeLabel: "07:00", isDone: false)])])
        let check = PendingCheck(dateKey: monday.key, routineID: id, isDone: true, at: .now)
        let waiting = original.applying([check])
        #expect(waiting.done == 0)
        #expect(waiting.percent == 0)
        #expect(waiting.items[0].requestedIsDone)
        #expect(waiting.hasPending)
        let cancel = PendingCheck(dateKey: monday.key, routineID: id, isDone: false, at: check.at.addingTimeInterval(1))
        #expect(!waiting.applying([check, cancel]).items[0].requestedIsDone)
        #expect(!original.applying([PendingCheck(dateKey: sunday.key, routineID: id, isDone: true, at: .now)]).hasPending)
    }

    @Test func acknowledgmentKeepsNewRequestsAndSurvivesBridgeRecreation() throws {
        let bridge = temporaryBridge()
        defer { try? FileManager.default.removeItem(at: bridge.directory) }
        let first = PendingCheck(dateKey: monday.key, routineID: UUID(), isDone: true, at: .now)
        try bridge.appendPending(first)
        let captured = try bridge.pendingChecks()
        let second = PendingCheck(dateKey: monday.key, routineID: first.routineID, isDone: false, at: first.at)
        try bridge.appendPending(second)
        try bridge.acknowledge(captured)
        let reopened = WidgetBridge(directory: bridge.directory)
        #expect(try reopened.pendingChecks().map(\.isDone) == [false])
        #expect(try #require(reopened.pendingChecks().first).at > first.at)
    }

    @Test func malformedJournalCannotBeOverwritten() throws {
        let bridge = temporaryBridge()
        defer { try? FileManager.default.removeItem(at: bridge.directory) }
        try FileManager.default.createDirectory(at: bridge.directory, withIntermediateDirectories: true)
        let url = bridge.directory.appendingPathComponent("widget-pending.json")
        let original = Data("broken but preserved".utf8)
        try original.write(to: url)
        #expect(throws: (any Error).self) {
            try bridge.appendPending(PendingCheck(dateKey: monday.key, routineID: UUID(), isDone: true, at: .now))
        }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func legacyInterruptedTakeIsRecovered() throws {
        let bridge = temporaryBridge()
        defer { try? FileManager.default.removeItem(at: bridge.directory) }
        try FileManager.default.createDirectory(at: bridge.directory, withIntermediateDirectories: true)
        let tap = PendingCheck(dateKey: monday.key, routineID: UUID(), isDone: true, at: .now)
        let legacy = bridge.directory.appendingPathComponent("widget-pending-interrupted.json")
        try JSONEncoder().encode([tap]).write(to: legacy)
        #expect(try bridge.pendingChecks() == [tap])
        try bridge.acknowledge([tap])
        #expect(try bridge.pendingChecks().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test func failedSaveRemainsPendingAndRetryPersistsWithoutDuplicates() async throws {
        let bridge = temporaryBridge()
        defer { try? FileManager.default.removeItem(at: bridge.directory) }
        let env = try CompanionEnv()
        let routine = env.addRoutine("물")
        let runtime = AppRuntime(store: env.store, notifications: RoutineNotifications(client: FakeNotificationClient(), defaults: testDefaults()), bridge: bridge)
        await runtime.refreshNow()
        try bridge.appendPending(PendingCheck(dateKey: monday.key, routineID: routine.id, isDone: true, at: .now.addingTimeInterval(1)))
        #expect(!runtime.drainWidgetChecks { check in
            try env.store.applyWidgetCheck(check, save: { throw Failure.diskFull })
        })
        #expect(try bridge.pendingChecks().count == 1)
        #expect(bridge.readSnapshot()?.day(monday.key)?.done == 0)
        #expect(try env.env.records.record(on: monday)?.checkList.first?.isDone == false)
        #expect(runtime.drainWidgetChecks())
        #expect(try bridge.pendingChecks().isEmpty)
        #expect(bridge.readSnapshot()?.day(monday.key)?.done == 1)
        let saved = try DayRecordService(context: env.env.freshContext()).record(on: monday)
        #expect(saved?.checkList.first?.isDone == true)
        #expect(try env.env.records.physicalRecords(on: monday).count == 1)
        #expect(saved?.checkList.count == 1)
    }

    @Test func diskJournalAndFinalCheckSurviveStoreReopen() throws {
        let bridge = temporaryBridge()
        defer { try? FileManager.default.removeItem(at: bridge.directory) }
        try FileManager.default.createDirectory(at: bridge.directory, withIntermediateDirectories: true)
        let storeURL = bridge.directory.appendingPathComponent("verification.store")
        defer { StoreLock.release(for: storeURL) }
        let routineID = try saveRapidTaps(to: storeURL, bridge: bridge)
        let reopened = try DaylogStore.makeContainer(.file(storeURL))
        let service = DayRecordService(context: reopened.mainContext)
        let saved = try #require(try service.record(on: monday))
        #expect(saved.checkList.filter { $0.routineID == routineID }.map(\.isDone) == [false])
        #expect(try service.physicalRecords(on: monday).count == 1)
        #expect(try WidgetBridge(directory: bridge.directory).pendingChecks().isEmpty)
    }

    private func saveRapidTaps(to url: URL, bridge: WidgetBridge) throws -> UUID {
        let container = try DaylogStore.makeContainer(.file(url))
        let routine = try RoutineService(context: container.mainContext).add(title: "물", today: monday)
        let store = AppStore(container: container, deviceID: "widget-test", clock: { monday })
        store.start()
        let runtime = AppRuntime(store: store, notifications: RoutineNotifications(client: FakeNotificationClient(), defaults: testDefaults()), bridge: bridge)
        let time = Date.now.addingTimeInterval(10)
        for (index, value) in [true, false, true, false].enumerated() {
            try bridge.appendPending(PendingCheck(dateKey: monday.key, routineID: routine.id, isDone: value, at: time.addingTimeInterval(Double(index))))
        }
        #expect(runtime.drainWidgetChecks())
        #expect(bridge.readSnapshot()?.day(monday.key)?.done == 0)
        return routine.id
    }

    @Test func unchangedCancellationStillSupersedesAnOlderDelayedCompletion() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("물")
        let time = Date.now.addingTimeInterval(10)
        try env.store.applyWidgetCheck(PendingCheck(dateKey: monday.key, routineID: routine.id, isDone: false, at: time))
        try env.store.applyWidgetCheck(PendingCheck(dateKey: monday.key, routineID: routine.id, isDone: false, at: time.addingTimeInterval(2)))
        try env.store.applyWidgetCheck(PendingCheck(dateKey: monday.key, routineID: routine.id, isDone: true, at: time.addingTimeInterval(1)))
        #expect(try env.env.records.record(on: monday)?.checkList.first?.isDone == false)
    }

    @Test func vacationSnapshotExcludesPercentAndKeepsChecks() throws {
        let saved = WidgetDay(dateKey: monday.key, groups: [WidgetGroup(id: UUID(), title: "아침", colorKey: "mint", items: [WidgetItem(routineID: UUID(), title: "물", timeLabel: "07:00", isDone: true)])], isVacation: true)
        #expect(saved.percent == nil)
        #expect(saved.ratio == nil)
        #expect(saved.done == 1)
        let roundtrip = try JSONDecoder().decode(WidgetDay.self, from: JSONEncoder().encode(saved))
        #expect(roundtrip == saved)
        // Previously published snapshots remain readable after upgrading.
        let legacy = Data("{\"dateKey\":\"2026-10-05\",\"groups\":[]}".utf8)
        #expect(try JSONDecoder().decode(WidgetDay.self, from: legacy).isVacation == nil)
    }
}
