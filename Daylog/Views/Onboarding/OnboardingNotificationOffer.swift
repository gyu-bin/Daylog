import Foundation

/// 시작 안내 3단계의 알림 안내가 어떤 모습이어야 하는지. 권한은 사용자가 [알림 켜기]를 눌렀을 때만 묻는다.
enum OnboardingNotificationOffer: Equatable {
    /// [알림 켜기] [나중에]를 보여 준다: 아직 물어본 적 없거나, 허용은 됐는데 이 기기에서 꺼 둔 상태.
    case ask
    /// 이미 켜져 있고 허용돼 있다. 안내만 한다.
    case alreadyOn
    /// 시스템에서 이미 거부돼 있다. 다시 묻지 않고(물어도 창이 뜨지 않는다) 설정 앱으로 안내한다.
    case blocked
    /// 권한 상태를 아직 모른다. 아무것도 보여 주지 않는다.
    case unavailable

    static func resolve(permission: NotificationPermission, isEnabled: Bool) -> OnboardingNotificationOffer {
        switch permission {
        case .unknown: return .unavailable
        case .denied: return .blocked
        case .notDetermined: return .ask
        case .authorized: return isEnabled ? .alreadyOn : .ask
        }
    }
}

/// [알림 켜기]를 누른 뒤의 결과.
enum OnboardingNotificationResult: Equatable {
    /// 허용됐고 이 기기의 루틴 알림을 켰다. `timedRoutines`는 예정 시간이 있어 알림이 울릴 루틴의 수.
    case enabled(timedRoutines: Int)
    /// 허용되지 않았다. 앱은 그대로 쓸 수 있다.
    case denied

    static func resolve(permission: NotificationPermission, timedRoutines: Int) -> OnboardingNotificationResult {
        permission == .authorized ? .enabled(timedRoutines: timedRoutines) : .denied
    }

    var message: String {
        switch self {
        case .enabled(let timedRoutines):
            return timedRoutines > 0
                ? "알림을 켰어요. 시간이 정해진 루틴 \(timedRoutines)개를 그 시간에 알려드려요."
                : "알림을 켰어요. 루틴에 시간을 정하면 그 시간에 알려드려요."
        case .denied:
            return "알림이 허용되지 않았어요. 앱은 그대로 쓸 수 있고, 나중에 설정 앱에서 RoutiMori의 알림을 허용하면 바로 울려요."
        }
    }

    var symbol: String {
        switch self {
        case .enabled: return "bell.badge.fill"
        case .denied: return "bell.slash"
        }
    }
}

/// 알림 안내를 따로 한 번 띄울지(iPhone·iPad). 시작 안내 3단계에서 이미 본 사람에게는 다시 띄우지 않는다.
///
/// 띄우는 경우: 시작 안내를 건너뛰어 3단계를 보지 못한 사람, 그리고 이 안내가 생기기 전부터 쓰던 사람 가운데
/// 알림을 아직 정하지 않은 사람. 한 번 보여 주면(또는 보여 줄 필요가 없다고 판단하면) 이 기기에 "끝남"으로 적는다.
enum NotificationGuidePolicy {
    enum Decision: Equatable {
        /// 지금 안내를 띄운다.
        case present
        /// 띄울 필요가 없다. "끝남"으로 적어 두고 다시 보지 않는다.
        case complete
        /// 아직 판단할 때가 아니다(시작 안내가 떠 있거나 권한 상태를 모른다). 다음에 다시 본다.
        case wait
        /// 이미 끝났다.
        case done
    }

    /// - Parameters:
    ///   - guideCompleted: 이 기기에서 안내를 이미 보여 줬거나 생략하기로 했다.
    ///   - onboardingCompleted: 시작 안내가 끝났다(떠 있는 동안에는 3단계가 안내를 맡는다).
    ///   - hasExplicitChoice: 사용자가 Daylog에서 루틴 알림을 직접 켜거나 끈 적이 있다.
    ///   - featureEnabled: 원격 UI 설정에서 이 안내를 꺼 두지 않았다.
    static func decide(
        guideCompleted: Bool, onboardingCompleted: Bool, permission: NotificationPermission,
        hasExplicitChoice: Bool, featureEnabled: Bool
    ) -> Decision {
        if guideCompleted { return .done }
        guard featureEnabled, onboardingCompleted, permission != .unknown else { return .wait }
        // 이미 허용·거부했거나 앱에서 직접 정한 사람에게는 묻지 않는다.
        if permission != .notDetermined || hasExplicitChoice { return .complete }
        return .present
    }
}
