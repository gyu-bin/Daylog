import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(CloudSyncMonitor.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var step = OnboardingStep.introduction
    @State private var draft = OnboardingRoutineDraft()
    @State private var didCreate = false
    @Environment(\.mobileUI) private var ui
    #if os(iOS)
    @Environment(RoutineNotifications.self) private var notifications
    /// [알림 켜기]를 누른 뒤의 결과. 누르기 전에는 nil.
    @State private var notificationResult: OnboardingNotificationResult?
    @State private var isRequestingNotifications = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                BrandIcon(size: 40)
                Text("RoutiMori 시작하기").font(.headline)
                Spacer()
                // 안내 전체를 닫는다. 단계 하나를 넘기는 것은 아래의 단추다.
                if step != .ready {
                    Button("안내 닫기", action: finish)
                        .buttonStyle(.borderless)
                        .accessibilityHint("남은 안내를 모두 건너뛰고 오늘 화면으로 갑니다.")
                }
            }
            Text("\(step.rawValue + 1) / 3")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .accessibilityLabel("3단계 중 \(step.rawValue + 1)단계")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case .introduction: introduction
                    case .createRoutine: createRoutine
                    case .ready: ready
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
            }
            .scrollDismissesKeyboard(.interactively)
            HStack(spacing: 8) {
                if step != .introduction {
                    Button("이전") { step = OnboardingStep(rawValue: step.rawValue - 1) ?? .introduction }
                }
                Spacer()
                switch step {
                case .introduction:
                    Button("다음") { step = .createRoutine }
                        .buttonStyle(.borderedProminent)
                case .createRoutine:
                    // 루틴을 만들지 않아도 다음 단계(준비 완료)로 간다.
                    Button(OnboardingFlow.skipRoutineTitle(hasRoutines: !store.activeRoutines.isEmpty)) { step = .ready }
                    Button("루틴 만들기", action: createRoutineFromDraft)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.validationMessage != nil)
                case .ready:
                    readyButtons
                }
            }
        }
        .padding(24)
        // 세 단계 중 가장 긴 단계(루틴 만들기)에 맞춘 높이. 더 크게 잡으면 소개 단계의 아래가 빈다.
        .frame(idealWidth: 520, maxWidth: 600, minHeight: 400, idealHeight: 460)
        .interactiveDismissDisabled()
        .keyboardDoneBar()
        #if os(iOS)
        // 안내를 보여 주기 위해 지금 상태만 읽는다. 권한은 [알림 켜기]를 눌렀을 때만 묻는다.
        .task { await notifications.refreshPermission() }
        #endif
    }

    /// 3단계의 아래 단추. 알림을 켤 수 있는 상태면 [나중에] [알림 켜기], 그 밖에는 [오늘 시작하기].
    @ViewBuilder
    private var readyButtons: some View {
        #if os(iOS)
        if showsNotificationGuide, notificationOffer == .ask, notificationResult == nil {
            Button("나중에", action: finish)
                .disabled(isRequestingNotifications)
                .accessibilityHint("알림 권한을 묻지 않고 오늘 화면으로 갑니다. 설정에서 나중에 켤 수 있어요.")
            Button("알림 켜기", action: enableNotifications)
                .buttonStyle(.borderedProminent)
                .disabled(isRequestingNotifications)
        } else {
            Button("오늘 시작하기", action: finish).buttonStyle(.borderedProminent)
        }
        #else
        Button("오늘 시작하기", action: finish).buttonStyle(.borderedProminent)
        #endif
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(verbatim: ui.string(.onboardingIntroTitle)).font(.title2.bold())
            Label("그룹으로 루틴을 정리하고 매일 체크해요.", systemImage: "checklist")
            Label("휴가는 통계에서 제외하고 기록은 보관해요.", systemImage: "sun.max")
            Label("식사 표시와 오늘 화면은 설정에서 바꿀 수 있어요.", systemImage: "slider.horizontal.3")
            Text("다른 기기의 기록이 있다면 iCloud 동기화 후 나타날 수 있어요. 이 안내를 열거나 건너뛰어도 기존 데이터는 바뀌지 않아요.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var createRoutine: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("첫 그룹과 루틴을 정해요").font(.title2.bold())
            if !store.activeRoutines.isEmpty {
                Text("사용할 수 있는 루틴이 \(store.activeRoutines.count)개 있어요. 그대로 시작하거나 새 루틴을 추가할 수 있어요.")
                    .font(.callout).foregroundStyle(.secondary)
            } else if sync.isWaitingForFirstImport {
                // 아직 iCloud에서 받아 오는 중일 수 있다. 다른 기기에서 쓰던 사람에게 새로 만들라고 재촉하지 않는다.
                Label("iCloud에서 기록을 확인하는 중이에요. 다른 기기에서 쓰던 루틴이 곧 나타날 수 있으니, 지금 만들지 않고 넘어가도 돼요.", systemImage: "icloud.and.arrow.down")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Picker("그룹", selection: $draft.groupID) {
                Text("새 그룹 이름 입력").tag(Optional<UUID>.none)
                ForEach(store.activeGroups) { group in
                    Text(group.title).tag(Optional(group.id))
                }
            }
            if draft.groupID == nil {
                TextField("그룹 이름", text: $draft.groupTitle, prompt: Text("예: 아침"))
            }
            TextField("루틴 이름", text: $draft.routineTitle, prompt: Text("예: 물 한 잔 마시기"))
                // 키보드가 올라오면 아래의 만들기 단추가 가려진다. Return으로도 만들 수 있게 한다.
                .submitLabel(.done)
                .onSubmit(createRoutineFromDraft)
            Text("매일 반복하는 루틴으로 만들어요. 요일과 시간은 루틴 화면에서 바꿀 수 있어요.")
                .font(.caption).foregroundStyle(.secondary)
            if let message = draft.validationMessage, !draft.routineTitle.isEmpty || !draft.groupTitle.isEmpty {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            if let error = store.errorMessage {
                Text(error).font(.callout).foregroundStyle(.red)
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(Theme.accent)
            Text(didCreate ? "루틴을 사용할 준비가 됐어요." : "준비됐어요.").font(.title2.bold())
            Text(store.activeRoutines.isEmpty ? "루틴은 루틴 화면에서 언제든 추가할 수 있어요." : "오늘 화면에서 루틴을 체크하며 시작해 보세요.")
            Text("오늘 화면의 카드는 순서를 바꾸거나 숨길 수 있어요.")
                .font(.callout).foregroundStyle(.secondary)
            #if os(iOS)
            notificationGuide
            #endif
        }
    }

    #if os(iOS)
    private var notificationOffer: OnboardingNotificationOffer {
        OnboardingNotificationOffer.resolve(permission: notifications.permission, isEnabled: notifications.isEnabled)
    }

    /// 알림 안내를 보여 줄지: 권한 상태를 알고 있고, 원격 UI 설정에서 꺼 두지 않았을 때.
    private var showsNotificationGuide: Bool {
        ui.showsOnboardingNotificationGuide && notificationOffer != .unavailable
    }

    /// 알림 안내. 권한 상태를 아직 모르면 아무것도 보여 주지 않는다. 따로 띄우는 안내와 같은 본문이다.
    @ViewBuilder
    private var notificationGuide: some View {
        if showsNotificationGuide {
            NotificationGuideCard(offer: notificationOffer, result: notificationResult)
        }
    }

    /// [알림 켜기]: 결과를 보여 주고, [오늘 시작하기]로 오늘 화면에 간다.
    private func enableNotifications() {
        guard !isRequestingNotifications else { return }
        isRequestingNotifications = true
        Task {
            notificationResult = await NotificationGuideActions.enable(notifications: notifications, store: store)
            isRequestingNotifications = false
        }
    }
    #endif

    private func createRoutineFromDraft() {
        guard draft.validationMessage == nil else { return }
        if store.createOnboardingRoutine(draft) {
            didCreate = true
            step = .ready
        }
    }

    private func finish() {
        #if os(iOS)
        // 3단계에서 알림 안내를 봤으면 따로 띄우지 않는다. 그 전에 닫았으면 화면의 뿌리가 한 번 띄운다.
        if step == .ready, showsNotificationGuide { preferences.completeNotificationGuide() }
        #endif
        preferences.completeOnboarding()
        store.leaveSheet(to: .dashboard)
        store.goToToday()
        dismiss()
    }
}

/// 시작 안내의 단계 이동 규칙. 2단계는 루틴을 만들든 넘기든 3단계(준비 완료)로 간다.
enum OnboardingFlow {
    /// 2단계에서 루틴을 만들지 않고 넘어가는 단추의 이름.
    static func skipRoutineTitle(hasRoutines: Bool) -> String {
        hasRoutines ? "현재 루틴으로 계속" : "나중에 설정하기"
    }
}
