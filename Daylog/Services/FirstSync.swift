import Foundation
import Observation

/// 새 기기에서 처음 열었을 때, 시작 안내보다 먼저 거치는 "iCloud 기록 확인" 단계의 상태.
enum FirstSyncPhase: Equatable {
    /// 기록을 받는 중일 수 있다. 안내와 로딩 표시만 보여 준다.
    case waiting
    /// iCloud를 쓸 수 없다(로그인 안 됨, 사용 제한). 이유를 알리고 이 기기에서만 쓸지 고르게 한다.
    case unavailable(CloudSyncMonitor.Account)
    /// 오래 걸리거나 오류가 났다. 다시 확인할지, 먼저 쓸지 고르게 한다. 값은 덧붙일 설명(오류 내용, 계정 상태).
    case stalled(String?)
    /// 기록이 들어왔다. 시작 안내 없이 오늘 화면으로 간다.
    case found
    /// 가져오기가 끝나고 한동안 조용한데 기록이 없다. 시작 안내로 넘어간다.
    /// "새 사용자"라고 확정한 것은 아니다. 시작 안내도 기록이 나중에 올 수 있다고 알리고, 온 기록은 그대로 합쳐진다.
    case empty
}

/// 무엇을 보여 줄지 정하는 규칙. 시스템이 알려 주는 값에서 계산만 한다.
///
/// CloudKit은 "다 받았다"를 알려 주지 않는다. 가져오기 한 번이 끝났다는 알림은 여러 묶음 중 하나일 수 있어서,
/// 그 알림만으로 기록이 없다고 보지 않는다. 가져오기가 돌고 있지 않고, 마지막으로 끝난 뒤 얼마간 조용할 때에만 넘어간다.
enum FirstSyncPolicy {
    /// 마지막 가져오기가 끝난 뒤 이만큼 조용하면 지금은 더 올 것이 없다고 본다.
    static let settleSeconds: TimeInterval = 6
    /// 가져오기가 한 번도 끝나지 않은 채 이만큼 지나면 계속 기다리게 하지 않는다.
    static let stallSeconds: TimeInterval = 30
    /// 오류가 보고된 뒤에는 이만큼만 더 기다린다(곧바로 다시 시도해 성공하는 일이 흔하다).
    static let errorGraceSeconds: TimeInterval = 10

    static func phase(
        hasRecords: Bool, account: CloudSyncMonitor.Account, isImporting: Bool, lastImportAt: Date?,
        errorMessage: String?, waitingSince: Date, now: Date
    ) -> FirstSyncPhase {
        // 기록이 보이면 다른 조건과 상관없이 끝이다(계정 확인이 늦거나 오류가 남아 있어도).
        if hasRecords { return .found }
        switch account {
        case .noAccount, .restricted:
            return .unavailable(account)
        case .temporarilyUnavailable, .unknown:
            return .stalled(account.title)
        case .notConfigured:
            // 동기화하지 않는 빌드에서는 이 단계를 켜지 않는다. 켜졌다면 기다릴 것이 없다.
            return .empty
        case .checking, .available:
            break
        }
        let waited = now.timeIntervalSince(waitingSince)
        if !isImporting {
            // 풀리지 않은 오류가 있으면 "없다"고 넘어가지 않는다. 앞서 끝난 가져오기가 있어도, 그 뒤의 가져오기가
            // 실패했을 수 있다(오류는 다음 성공 때 지워진다). 잠깐 기다렸다가 사용자가 고르게 한다.
            if let errorMessage {
                return waited >= errorGraceSeconds ? .stalled(errorMessage) : .waiting
            }
            if let lastImportAt {
                return now.timeIntervalSince(lastImportAt) >= settleSeconds ? .empty : .waiting
            }
        }
        return waited >= stallSeconds ? .stalled(errorMessage) : .waiting
    }

    /// 이 단계를 켤지. 앱을 켤 때 한 번 정한다.
    ///
    /// 시작 안내를 아직 끝내지 않았고(이 기기에서 처음), 저장소에 사용자의 기록이 없고, iCloud를 쓰는 빌드일 때만 켠다.
    /// 이미 쓰던 기기와 기록이 있는 기기는 지금까지와 똑같이 열린다.
    static func shouldArm(onboardingCompleted: Bool, hasRecords: Bool, syncEnabled: Bool) -> Bool {
        !onboardingCompleted && !hasRecords && syncEnabled
    }
}

/// 첫 동기화 안내가 떠 있는지와, 기다리기 시작한 때. 창이 여러 개여도 하나를 함께 본다.
@MainActor
@Observable
final class FirstSyncGate {
    static let shared = FirstSyncGate()

    /// 안내가 떠 있다. 이 동안에는 시작 안내와 알림 안내를 올리지 않는다.
    private(set) var isActive = false
    /// 기다리기 시작한 때. [다시 확인]을 누르면 새로 센다.
    private(set) var waitingSince = Date.now
    /// 경과 시간을 재는 기준. 안내 화면이 1초마다 올린다.
    private(set) var now = Date.now

    func arm(onboardingCompleted: Bool, hasRecords: Bool, syncEnabled: Bool, now: Date = .now) {
        guard FirstSyncPolicy.shouldArm(
            onboardingCompleted: onboardingCompleted, hasRecords: hasRecords, syncEnabled: syncEnabled
        ) else { return }
        isActive = true
        waitingSince = now
        self.now = now
    }

    func tick(_ date: Date = .now) {
        now = date
    }

    /// [다시 확인]: 처음부터 다시 기다린다.
    func retry(now: Date = .now) {
        waitingSince = now
        self.now = now
    }

    /// 안내를 내린다(기록이 왔거나, 기록이 없어 시작 안내로 넘어가거나, 사용자가 먼저 쓰기로 했다).
    /// 이번 실행에서는 다시 올리지 않는다.
    func finish() {
        isActive = false
    }
}
