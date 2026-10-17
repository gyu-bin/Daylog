import SwiftUI

/// 새 기기에서 처음 열었을 때, 다른 기기의 기록이 iCloud에서 오는지 확인하는 동안 화면을 덮는 안내.
///
/// 빈 화면을 보고 새로 시작하는 것으로 오해하지 않게, 기록을 받는 동안에는 루틴을 만들라고 권하지 않는다.
/// 기록이 오면 시작 안내 없이 오늘 화면으로 가고, 오지 않으면 시작 안내로 넘어간다. 얼마나 받았는지는 알 수 없어서
/// 진행률은 보여 주지 않는다. 무엇을 보여 줄지는 `FirstSyncPolicy`가 정한다.
struct FirstSyncView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSyncMonitor.self) private var sync
    @Environment(DevicePreferences.self) private var preferences
    let gate: FirstSyncGate
    /// 설정의 미리보기: 실제 동기화 상태 대신 이 상태를 보여 준다. 단추는 아무 일도 하지 않고, 화면을 닫지도 않는다
    /// (iCloud 계정 확인·동기화·시작 안내 같은 실제 동작을 하지 않는다).
    var preview: FirstSyncPhase?
    /// 미리보기에서 화면 아래에 덧붙이는 안내(이 상태가 실제로 언제 보이는지).
    var previewNote: String?
    /// [다시 확인]을 누른 직후. 상태가 그대로여도 눌렸다는 것을 보여 준다.
    @State private var isRechecking = false

    private var phase: FirstSyncPhase {
        if let preview { return preview }
        return FirstSyncPolicy.phase(
            hasRecords: store.hasUserRecords, account: sync.account, isImporting: sync.isImporting,
            lastImportAt: sync.lastImportAt, errorMessage: sync.lastErrorMessage,
            waitingSince: gate.waitingSince, now: gate.now
        )
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var usesRoutimori: Bool { PioCharacter.isEnabled }

    var body: some View {
        let phase = phase
        let kind = SyncSceneKind(phase, isPreview: preview != nil)
        GeometryReader { proxy in
            // 글자를 크게 쓰면 한 화면을 넘을 수 있다. 넘치면 스크롤하고, 아니면 가운데에 둔다.
            // 그림은 화면 높이에 맞춰 줄인다(작은 iPhone에서도 글과 단추가 잘리지 않게).
            let proposedHeight = min(400, max(210, proxy.size.height * 0.48))
            let sceneHeight = usesRoutimori ? min(proposedHeight, max(140, proxy.size.width - 48)) : proposedHeight
            ScrollView {
                VStack(spacing: 14) {
                    if usesRoutimori { RoutimoriSyncBrand() }
                    SyncScene(kind: kind, height: sceneHeight)
                        .id(kind)
                        .transition(.opacity)
                    if usesRoutimori {
                        PioAppearanceNotice(appearance: PioAppearanceCoordinator.shared.resolve(
                            level: store.growth.level, context: kind.pioAppearanceContext))
                    }
                    content(phase)
                        .id(kind)
                        .transition(.opacity)
                    if let previewNote {
                        Label(previewNote, systemImage: "info.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.cardBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.top, 4)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: kind)
                .frame(maxWidth: 440)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            LinearGradient(colors: usesRoutimori ? RoutimoriSyncStyle.background(dark: colorScheme == .dark) : SyncSceneBackground.colors(kind, dark: colorScheme == .dark), startPoint: .top, endPoint: .bottom)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: kind)
                .ignoresSafeArea()
        }
        .accessibilityAddTraits(.isModal)
        .task {
            // 경과 시간으로 "오래 걸린다"와 "더 올 것이 없다"를 가리므로 1초마다 다시 본다(미리보기는 하지 않는다).
            guard preview == nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                gate.tick()
            }
        }
        .onChange(of: phase, initial: true) { _, phase in
            guard preview == nil else { return }
            resolve(phase)
        }
    }

    @ViewBuilder
    private func content(_ phase: FirstSyncPhase) -> some View {
        switch phase {
        case .found where preview != nil:
            // 실제로는 기록을 찾으면 이 화면 없이 바로 오늘 화면으로 간다. 미리보기에서만 그 순간을 보여 준다.
            message(
                title: usesRoutimori ? "동기화가 완료됐어요!" : "준비됐어요!\n오늘도 함께해요.",
                detail: usesRoutimori ? "다른 기기의 기록을 확인했어요.\n오늘도 루티모리와 함께해요." : "다른 기기의 기록을 확인했어요.\n이제 Daylog를 시작할 수 있어요."
            ) {
                Button(action: {}) {
                    Text(usesRoutimori ? "확인" : "Daylog 시작하기").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(usesRoutimori ? RoutimoriSyncStyle.green : Color(red: 0.3, green: 0.68, blue: 0.34))
                .controlSize(.large)
                .frame(maxWidth: 320)
            }
        case .waiting, .found, .empty:
            // 기록을 찾았거나 없다고 본 순간에는 곧 이 화면이 걷힌다. 그 사이에 문구를 바꿔 깜빡이지 않게 한다.
            // 얼마나 받았는지는 알 수 없어 진행률·완료율은 보여 주지 않는다(점과 왕복 막대는 기다리는 표시일 뿐이다).
            message(
                title: usesRoutimori ? "루티모리가 iCloud 기록을\n확인하고 있어요" : "새싹이가 iCloud 기록을\n확인하고 있어요!",
                detail: "다른 기기의 소중한 기록을\n가져와 정리하고 있어요."
            ) {
                if usesRoutimori { RoutimoriSyncActivity() } else { SyncWaitingDots() }
            }
        case .unavailable(let account):
            // 계정 문제는 네트워크 문제라고 말하지 않는다.
            message(
                title: account.title,
                detail: account == .restricted
                    ? "스크린 타임이나 기기 관리 설정에서 iCloud 사용이 막혀 있어요. 다른 기기의 기록은 불러올 수 없지만, \(Platform.thisDevice)에만 기록하며 사용할 수 있어요."
                    : "다른 기기의 기록을 불러오려면 기기의 설정에서 iCloud에 로그인해 주세요. 로그인하지 않아도 \(Platform.thisDevice)에만 기록하며 사용할 수 있어요."
            ) {
                choices
            }
        case .stalled(let note):
            message(
                title: "아직 기록을 확인하지 못했어요.",
                detail: note == nil
                    ? "네트워크 상태를 확인하고 다시 시도해 보세요.\n지금 시작해도 이 기기의 기록은 안전하고, 다른 기기의 기록은 도착하는 대로 나타나요."
                    : "동기화 중에 문제가 생겼어요. 네트워크 상태를 확인하고 다시 시도해 보세요.\n지금 시작해도 이 기기의 기록은 안전해요."
            ) {
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                choices
            }
        }
    }

    /// 제목, 설명, 그 아래의 내용. 그림(`SyncScene`)은 위에 따로 있다.
    private func message(title: String, detail: String, @ViewBuilder footer: () -> some View) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text(title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 12) {
                footer()
            }
            .padding(.top, 4)
        }
    }

    /// 기다리지 않아도 되는 두 가지 길. 어느 쪽도 기록을 지우거나 바꾸지 않는다.
    private var choices: some View {
        VStack(spacing: 10) {
            Button(action: { if preview == nil { recheck() } }) {
                Text(isRechecking ? "확인 중…" : (usesRoutimori ? "다시 시도하기" : "다시 확인하기")).font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(usesRoutimori ? RoutimoriSyncStyle.green : Color(red: 0.25, green: 0.55, blue: 0.95))
            .disabled(isRechecking)
            Button(action: { if preview == nil { gate.finish() } }) {
                Text(usesRoutimori ? "나중에 하기" : "일단 시작하기").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("시작 안내로 넘어갑니다. 다른 기기의 기록이 나중에 오면 그대로 합쳐져요.")
        }
        .controlSize(.large)
        .frame(maxWidth: 320)
    }

    /// 계정 상태를 다시 묻고 처음부터 다시 기다린다. 동기화를 강제로 돌리는 공식 방법은 없다.
    private func recheck() {
        isRechecking = true
        sync.refreshAccountStatus()
        gate.retry()
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            isRechecking = false
        }
    }

    private func resolve(_ phase: FirstSyncPhase) {
        switch phase {
        case .found:
            // 다른 기기에서 쓰던 사람이다. 시작 안내를 다시 보여 주지 않고 오늘 화면으로 간다.
            preferences.completeOnboarding()
            store.section = .dashboard
            store.goToToday()
            gate.finish()
        case .empty:
            // 시작 안내가 이어서 올라온다.
            gate.finish()
        case .waiting, .unavailable, .stalled:
            break
        }
    }
}
