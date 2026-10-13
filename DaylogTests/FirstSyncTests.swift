import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 새 기기의 첫 동기화 안내: 언제 켜고, 무엇을 보여 주고, 언제 넘어가는가.
@MainActor
struct FirstSyncTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func phase(
        hasRecords: Bool = false, account: CloudSyncMonitor.Account = .available, isImporting: Bool = false,
        importedAfter: TimeInterval? = nil, error: String? = nil, elapsed: TimeInterval
    ) -> FirstSyncPhase {
        FirstSyncPolicy.phase(
            hasRecords: hasRecords, account: account, isImporting: isImporting,
            lastImportAt: importedAfter.map { start.addingTimeInterval($0) }, errorMessage: error,
            waitingSince: start, now: start.addingTimeInterval(elapsed)
        )
    }

    // MARK: - 켜는 조건

    @Test func armsOnlyOnAFreshDeviceThatSyncs() {
        #expect(FirstSyncPolicy.shouldArm(onboardingCompleted: false, hasRecords: false, syncEnabled: true))
        // 이미 쓰던 기기는 그대로 열린다.
        #expect(!FirstSyncPolicy.shouldArm(onboardingCompleted: true, hasRecords: false, syncEnabled: true))
        // 기록이 있는 기기도 그대로 열린다(시작 안내만 남아 있던 경우).
        #expect(!FirstSyncPolicy.shouldArm(onboardingCompleted: false, hasRecords: true, syncEnabled: true))
        // 동기화하지 않는 빌드는 기다릴 것이 없다.
        #expect(!FirstSyncPolicy.shouldArm(onboardingCompleted: false, hasRecords: false, syncEnabled: false))
    }

    @Test func gateStaysDownOnceFinished() {
        let gate = FirstSyncGate()
        gate.arm(onboardingCompleted: true, hasRecords: false, syncEnabled: true, now: start)
        #expect(!gate.isActive)
        gate.arm(onboardingCompleted: false, hasRecords: false, syncEnabled: true, now: start)
        #expect(gate.isActive)
        #expect(gate.waitingSince == start)
        // [다시 확인]은 처음부터 다시 센다.
        let later = start.addingTimeInterval(40)
        gate.retry(now: later)
        #expect(gate.waitingSince == later)
        #expect(gate.now == later)
        gate.finish()
        #expect(!gate.isActive)
    }

    // MARK: - A. 기록을 받는 중

    @Test func waitsWhileNothingHasBeenImportedYet() {
        #expect(phase(account: .checking, elapsed: 0) == .waiting)
        #expect(phase(account: .available, elapsed: 12) == .waiting)
        // 가져오기가 돌고 있으면 앞서 끝난 가져오기가 있어도 계속 기다린다(여러 묶음으로 올 수 있다).
        #expect(phase(isImporting: true, importedAfter: 2, elapsed: 20) == .waiting)
    }

    @Test func recordsEndTheWaitWhateverElseIsGoingOn() {
        #expect(phase(hasRecords: true, elapsed: 1) == .found)
        #expect(phase(hasRecords: true, account: .checking, elapsed: 0) == .found)
        #expect(phase(hasRecords: true, account: .noAccount, elapsed: 0) == .found)
        #expect(phase(hasRecords: true, error: "오류", elapsed: 50) == .found)
    }

    // MARK: - B. 기록이 없는 경우

    @Test func oneFinishedImportIsNotEnoughToCallItEmpty() {
        // 가져오기가 막 끝났다: 아직 "없다"고 보지 않는다.
        #expect(phase(importedAfter: 3, elapsed: 4) == .waiting)
        #expect(phase(importedAfter: 3, elapsed: 3 + FirstSyncPolicy.settleSeconds - 0.5) == .waiting)
        // 끝난 뒤 한동안 조용하면 시작 안내로 넘어간다.
        #expect(phase(importedAfter: 3, elapsed: 3 + FirstSyncPolicy.settleSeconds) == .empty)
        // 조용한 사이 다음 가져오기가 시작되면 다시 기다린다.
        #expect(phase(isImporting: true, importedAfter: 3, elapsed: 3 + FirstSyncPolicy.settleSeconds) == .waiting)
        // 오래 기다린 뒤에 가져오기가 끝났어도 끝난 때부터 다시 조용한지 본다.
        #expect(phase(importedAfter: 28, elapsed: 29) == .waiting)
    }

    // MARK: - C. iCloud를 쓸 수 없음

    @Test func missingOrRestrictedAccountIsExplainedRightAway() {
        #expect(phase(account: .noAccount, elapsed: 0) == .unavailable(.noAccount))
        #expect(phase(account: .restricted, elapsed: 0) == .unavailable(.restricted))
    }

    // MARK: - D. 오류와 오랜 대기

    @Test func neverWaitsForever() {
        #expect(phase(elapsed: FirstSyncPolicy.stallSeconds - 1) == .waiting)
        #expect(phase(elapsed: FirstSyncPolicy.stallSeconds) == .stalled(nil))
        // 가져오기가 끝나지 않고 계속 돌기만 해도 마찬가지다.
        #expect(phase(isImporting: true, elapsed: FirstSyncPolicy.stallSeconds) == .stalled(nil))
        // 계정을 확인하지 못하는 상태는 바로 알린다.
        #expect(phase(account: .temporarilyUnavailable, elapsed: 0)
            == .stalled(CloudSyncMonitor.Account.temporarilyUnavailable.title))
        if case .stalled(let note) = phase(account: .unknown("확인 불가"), elapsed: 0) {
            #expect(note?.contains("확인 불가") == true)
        } else {
            Issue.record("계정 상태를 모르면 기다리게 두지 않는다")
        }
    }

    @Test func reportedErrorShortensTheWait() {
        #expect(phase(error: "네트워크 오류", elapsed: FirstSyncPolicy.errorGraceSeconds - 1) == .waiting)
        #expect(phase(error: "네트워크 오류", elapsed: FirstSyncPolicy.errorGraceSeconds) == .stalled("네트워크 오류"))
        // 오류 뒤에 다시 가져오는 중이면 조금 더 기다린다.
        #expect(phase(isImporting: true, error: "네트워크 오류", elapsed: FirstSyncPolicy.errorGraceSeconds) == .waiting)
    }

    @Test func failedImportAfterAnEarlierOneDoesNotCountAsEmpty() {
        // 첫 가져오기는 끝났지만 그 뒤의 가져오기가 실패했다: 조용해 보여도 시작 안내로 넘기지 않는다.
        #expect(phase(importedAfter: 2, error: "네트워크 오류", elapsed: 2 + FirstSyncPolicy.settleSeconds) == .waiting)
        #expect(phase(importedAfter: 2, error: "네트워크 오류", elapsed: FirstSyncPolicy.errorGraceSeconds)
            == .stalled("네트워크 오류"))
        #expect(phase(importedAfter: 2, error: "네트워크 오류", elapsed: 120) == .stalled("네트워크 오류"))
        // 다시 성공해 오류가 지워지면, 그 가져오기가 끝난 때부터 조용한지 본다.
        #expect(phase(importedAfter: 40, elapsed: 41) == .waiting)
        #expect(phase(importedAfter: 40, elapsed: 40 + FirstSyncPolicy.settleSeconds) == .empty)
    }

    // MARK: - 기록이 있는지

    @Test func emptyStoreHasNoUserRecordsAndAnyEntryCounts() throws {
        let container = try DaylogStore.makeContainer(.inMemory)
        let store = AppStore(container: container, clock: { Day(year: 2026, month: 10, day: 14) })
        // 실제 앱처럼 이 기기의 정보 줄도 쓰게 한다.
        store.tracksDevice = true
        store.start()
        #expect(!store.devices.isEmpty)
        // 앱이 스스로 만드는 오늘의 빈 기록과 기기 정보는 세지 않는다.
        #expect(!store.hasUserRecords)
        _ = store.addGroup(title: "아침")
        #expect(store.hasUserRecords)
    }

    @Test func mealTextAloneCountsAsUserRecords() throws {
        let container = try DaylogStore.makeContainer(.inMemory)
        let store = AppStore(container: container, clock: { Day(year: 2026, month: 10, day: 14) })
        store.start()
        store.setText("토스트", at: \.breakfast)
        store.flush()
        #expect(store.groups.isEmpty)
        #expect(store.hasUserRecords)
    }
}
