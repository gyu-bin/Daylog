import Foundation
import Testing
@testable import Daylog

/// 시작 안내 3단계의 알림 안내: 언제 묻고, 언제 묻지 않고, 결과를 어떻게 알리는가.
@MainActor
struct OnboardingNotificationTests {
    @Test func offerAsksOnlyWhenTheUserCanStillDecide() {
        // 아직 물어본 적 없으면 [알림 켜기] [나중에].
        #expect(OnboardingNotificationOffer.resolve(permission: .notDetermined, isEnabled: false) == .ask)
        // 허용은 돼 있는데 이 기기에서 꺼 둔 경우에도 켤 수 있게 한다(시스템 창은 다시 뜨지 않는다).
        #expect(OnboardingNotificationOffer.resolve(permission: .authorized, isEnabled: false) == .ask)
        // 이미 켜져 있으면 안내만.
        #expect(OnboardingNotificationOffer.resolve(permission: .authorized, isEnabled: true) == .alreadyOn)
        // 시스템에서 거부돼 있으면 다시 묻지 않는다(켜 달라는 설정이 남아 있어도).
        #expect(OnboardingNotificationOffer.resolve(permission: .denied, isEnabled: false) == .blocked)
        #expect(OnboardingNotificationOffer.resolve(permission: .denied, isEnabled: true) == .blocked)
        // 상태를 모르면 아무것도 보여 주지 않는다.
        #expect(OnboardingNotificationOffer.resolve(permission: .unknown, isEnabled: false) == .unavailable)
    }

    @Test func resultMessagesMatchTheOutcome() {
        let allowed = OnboardingNotificationResult.resolve(permission: .authorized, timedRoutines: 2)
        #expect(allowed == .enabled(timedRoutines: 2))
        #expect(allowed.message.contains("2개"))
        // 시간이 정해진 루틴이 없으면 그렇게 알려 준다(아무것도 울리지 않는 이유).
        let noTimes = OnboardingNotificationResult.resolve(permission: .authorized, timedRoutines: 0)
        #expect(noTimes.message.contains("시간을 정하면"))
        // 거부해도 앱을 쓸 수 있다고 알린다.
        let denied = OnboardingNotificationResult.resolve(permission: .denied, timedRoutines: 3)
        #expect(denied == .denied)
        #expect(denied.message.contains("그대로 쓸 수 있"))
        #expect(OnboardingNotificationResult.resolve(permission: .notDetermined, timedRoutines: 1) == .denied)
    }

    @Test func turningOnFromOnboardingEnablesDeviceNotificationsAndKeepsPerRoutineMutes() async {
        let client = FakeNotificationClient()
        client.status = .notDetermined
        client.answer = .authorized
        let defaults = testDefaults()
        let muted = UUID()
        let notifications = RoutineNotifications(client: client, defaults: defaults)
        notifications.setMuted(muted, true)
        // 화면을 여는 것만으로는 묻지 않는다.
        await notifications.refreshPermission()
        #expect(client.requests == 0)
        #expect(OnboardingNotificationOffer.resolve(permission: notifications.permission, isEnabled: notifications.isEnabled) == .ask)
        // [알림 켜기]
        await notifications.setEnabled(true)
        #expect(client.requests == 1)
        #expect(notifications.isEnabled && notifications.isActive)
        // 루틴별로 꺼 둔 알림은 그대로다.
        #expect(notifications.isMuted(muted))
        #expect(OnboardingNotificationOffer.resolve(permission: notifications.permission, isEnabled: notifications.isEnabled) == .alreadyOn)
    }

    @Test func denialLeavesTheAppUsableAndIsNotAskedAgain() async {
        let client = FakeNotificationClient()
        client.status = .notDetermined
        client.answer = .denied
        let notifications = RoutineNotifications(client: client, defaults: testDefaults())
        await notifications.setEnabled(true)
        #expect(notifications.permission == .denied)
        #expect(!notifications.isActive)
        // 다음에 시작 안내를 다시 열면 묻는 단추 대신 설정 안내가 나온다.
        #expect(OnboardingNotificationOffer.resolve(permission: notifications.permission, isEnabled: notifications.isEnabled) == .blocked)
    }
}
