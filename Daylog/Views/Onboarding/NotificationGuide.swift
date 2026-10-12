#if os(iOS)
import SwiftUI

/// 알림 안내의 본문: 제목, 설명, 지금 상태나 결과. 시작 안내 3단계와 따로 띄우는 안내가 함께 쓴다.
struct NotificationGuideCard: View {
    @Environment(\.mobileUI) private var ui
    let offer: OnboardingNotificationOffer
    /// [알림 켜기]를 누른 뒤의 결과. 누르기 전에는 nil.
    let result: OnboardingNotificationResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(verbatim: ui.string(.onboardingNotificationTitle))
            } icon: {
                Image(systemName: "bell.badge")
            }
            .font(.headline)
            Text(verbatim: ui.string(.onboardingNotificationBody))
                .font(.callout)
                .foregroundStyle(.secondary)
            if let result {
                Label(result.message, systemImage: result.symbol)
                    .font(.callout)
                    .foregroundStyle(result == .denied ? AnyShapeStyle(.orange) : AnyShapeStyle(Theme.accent))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            } else {
                switch offer {
                case .ask:
                    Text("시간을 정한 루틴만 알려요. 지금 켜지 않아도 설정 → 알림에서 언제든 켤 수 있어요.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .alreadyOn:
                    Label("이 기기에서 루틴 알림이 켜져 있어요.", systemImage: "checkmark.circle")
                        .font(.callout).foregroundStyle(Theme.accent)
                case .blocked:
                    // 이미 거부돼 있으면 다시 물어도 창이 뜨지 않는다. 설정 앱으로 가는 길을 준다.
                    Text("지금은 \(Platform.thisDevice)의 설정에서 Daylog의 알림이 꺼져 있어요. 설정 앱에서 허용하면 루틴 시간에 알려드려요.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("알림 설정 열기") { Platform.openNotificationSettings() }
                        .font(.callout)
                        .padding(.top, 2)
                case .unavailable:
                    EmptyView()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// [알림 켜기]의 공통 동작. 여기서만 시스템 권한을 묻는다(이미 정해져 있으면 묻지 않는다).
/// 허용되면 이 기기의 루틴 알림을 켜고 예약을 맞춘다. 루틴별 알림 끄기 설정은 건드리지 않는다.
@MainActor
enum NotificationGuideActions {
    static func enable(notifications: RoutineNotifications, store: AppStore) async -> OnboardingNotificationResult {
        await notifications.setEnabled(true)
        AppRuntime.shared?.scheduleRefresh()
        let timed = store.activeRoutines.filter { TimeLabel.minutes($0.timeLabel) != nil }.count
        return .resolve(permission: notifications.permission, timedRoutines: timed)
    }
}

/// 따로 띄우는 알림 안내. 시작 안내를 건너뛴 사람과, 이 안내가 생기기 전부터 쓰던 사람에게 한 번 보여 준다.
/// 어떻게 닫든(나중에, 확인, 쓸어내리기) 이 기기에서는 다시 띄우지 않는다.
struct NotificationGuideSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(RoutineNotifications.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @State private var result: OnboardingNotificationResult?
    @State private var isRequesting = false

    private var offer: OnboardingNotificationOffer {
        OnboardingNotificationOffer.resolve(permission: notifications.permission, isEnabled: notifications.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                BrandIcon(size: 36)
                Text("알림").font(.headline)
            }
            NotificationGuideCard(offer: offer, result: result)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Spacer()
                if offer == .ask, result == nil {
                    Button("나중에") { dismiss() }
                        .disabled(isRequesting)
                        .accessibilityHint("알림 권한을 묻지 않고 닫습니다. 설정에서 나중에 켤 수 있어요.")
                    Button("알림 켜기") {
                        guard !isRequesting else { return }
                        isRequesting = true
                        Task {
                            result = await NotificationGuideActions.enable(notifications: notifications, store: store)
                            isRequesting = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequesting)
                } else {
                    Button("확인") { dismiss() }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(300), .medium])
        // 한 번 보여 줬으면 끝난 것이다(쓸어내려 닫아도 "나중에"와 같다).
        .onAppear { preferences.completeNotificationGuide() }
    }
}
#endif
