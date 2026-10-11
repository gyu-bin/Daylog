import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @State private var step = OnboardingStep.introduction
    @State private var draft = OnboardingRoutineDraft()
    @State private var didCreate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                BrandIcon(size: 40)
                Text("Daylog 시작하기").font(.headline)
                Spacer()
                Button("건너뛰기", action: finish)
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
            HStack {
                if step != .introduction {
                    Button("이전") { step = OnboardingStep(rawValue: step.rawValue - 1) ?? .introduction }
                }
                Spacer()
                if step == .ready {
                    Button("오늘 시작하기", action: finish).buttonStyle(.borderedProminent)
                } else {
                    Button(step == .createRoutine ? (store.activeRoutines.isEmpty ? "나중에 만들기" : "현재 루틴으로 계속") : "다음") {
                        step = step.next
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(idealWidth: 520, maxWidth: 600, minHeight: 440, idealHeight: 540)
        .interactiveDismissDisabled()
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("작은 루틴부터, 나만의 하루를.").font(.title2.bold())
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
            Text("매일 반복하는 루틴으로 만들어요. 요일과 시간은 루틴 화면에서 바꿀 수 있어요.")
                .font(.caption).foregroundStyle(.secondary)
            Button("입력한 루틴 만들기") {
                if store.createOnboardingRoutine(draft) {
                    didCreate = true
                    step = .ready
                }
            }
            .disabled(draft.validationMessage != nil)
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
            Text(store.activeRoutines.isEmpty ? "오늘 화면에서 언제든 루틴을 추가할 수 있어요." : "오늘 화면에서 루틴을 체크하며 시작해 보세요.")
            Text("설정에서 카드 순서를 바꾸고, 필요 없는 카드를 숨기세요. 오늘 루틴은 항상 남아 있어요.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func finish() {
        preferences.completeOnboarding()
        store.section = .dashboard
        store.goToToday()
        dismiss()
    }
}
