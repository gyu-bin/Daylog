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
            return "알림이 허용되지 않았어요. 앱은 그대로 쓸 수 있고, 나중에 설정 앱에서 Daylog의 알림을 허용하면 바로 울려요."
        }
    }

    var symbol: String {
        switch self {
        case .enabled: return "bell.badge.fill"
        case .denied: return "bell.slash"
        }
    }
}
