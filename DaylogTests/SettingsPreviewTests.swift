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

    @Test func syncPreviewOffersThreeDistinctScenesWithoutProgressNumbers() {
        // 고를 것은 세 가지뿐이고, 셋이 서로 다른 장면이다.
        #expect(SyncPreviewSample.allCases.map(\.title) == ["기록 받는 중", "준비 완료", "연결 문제"])
        let kinds = SyncPreviewSample.allCases.map { SyncSceneKind($0.phase(), isPreview: true) }
        #expect(kinds == [.receiving, .ready, .trouble])
        // 연결 문제의 실제 경우(오래 걸림·오류·로그인 안 됨)는 모두 같은 장면을 쓴다.
        for phase in [FirstSyncPhase.stalled(nil), .stalled("오류"), .unavailable(.noAccount), .unavailable(.restricted)] {
            #expect(SyncSceneKind(phase, isPreview: false) == .trouble)
        }
        // 실제 화면에서는 기록을 찾아도 "준비 완료"를 보여 주지 않는다(곧바로 오늘 화면으로 간다).
        #expect(SyncSceneKind(.found, isPreview: false) == .receiving && SyncSceneKind(.empty, isPreview: false) == .receiving)
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
