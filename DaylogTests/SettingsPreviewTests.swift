import Foundation
import Testing
@testable import Daylog

/// 설정의 미리보기(휴가 화면, 동기화 화면): 예시 값만 쓰고 실제 휴가·동기화 상태를 건드리지 않는다.
@MainActor
struct SettingsPreviewTests {
    @Test func vacationPreviewUsesASampleFiveDayPeriod() throws {
        let today = day("2026-10-14")
        let info = try #require(VacationRestPreview.sampleInfo(today: today))
        #expect(info.title == "휴가 2일째 / 총 5일")
        #expect(info.start == day("2026-10-13") && info.end == day("2026-10-17"))
    }

    @Test func syncPreviewCoversEveryStateWithoutProgressNumbers() {
        let phases = SyncPreviewSample.allCases.map(\.phase)
        #expect(phases.contains(.waiting) && phases.contains(.found) && phases.contains(.stalled(nil)))
        #expect(phases.contains(.unavailable(.noAccount)))
        #expect(phases.contains { if case .stalled(let note?) = $0 { return note.hasPrefix("예시") } else { return false } })
        for sample in SyncPreviewSample.allCases {
            #expect(!sample.note.contains("%") && !sample.title.isEmpty)
        }
    }

    @Test func previewsLeaveTheRealGateAndStoreAlone() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, clock: { day("2026-10-14") })
        store.start()
        let before = (FirstSyncGate.shared.isActive, store.vacationPeriods)
        // 미리보기는 자기 안내 상태를 따로 만든다. 만들어도 실제 안내·휴가는 그대로다.
        let previewGate = FirstSyncGate()
        _ = FirstSyncView(gate: previewGate, preview: .stalled(nil))
        _ = VacationRestPreview.sampleInfo(today: store.today)
        #expect(previewGate !== FirstSyncGate.shared && !previewGate.isActive)
        #expect(FirstSyncGate.shared.isActive == before.0 && store.vacationPeriods == before.1)
        #expect(store.vacationPeriods.isEmpty)
    }
}
