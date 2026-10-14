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

    var body: some View {
        let phase = phase
        GeometryReader { proxy in
            // 글자를 크게 쓰면 한 화면을 넘을 수 있다. 넘치면 스크롤하고, 아니면 가운데에 둔다.
            ScrollView {
                content(phase)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            ZStack {
                Theme.windowBackground
                LinearGradient(colors: [Theme.accentWash, .clear], startPoint: .top, endPoint: .center)
            }
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
                badge: "checkmark.icloud", tint: Theme.accent, floats: false, pose: .happy,
                title: "기록을 모두 불러왔어요!",
                detail: "다른 기기에서 쓰던 루틴과 기록이 이 기기에도 왔어요. 실제로는 이 순간 바로 오늘 화면으로 넘어가요."
            ) {
                EmptyView()
            }
        case .waiting, .found, .empty:
            // 기록을 찾았거나 없다고 본 순간에는 곧 이 화면이 걷힌다. 그 사이에 문구를 바꿔 깜빡이지 않게 한다.
            message(
                badge: nil, tint: Theme.accent, floats: true,
                title: "새싹이가 기록을 확인하고 있어요!",
                detail: "다른 기기에서 사용하던 루틴과 기록을 불러오고 있어요. 잠시만 기다려 주세요."
            ) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("동기화 중...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        case .unavailable(let account):
            message(
                badge: "icloud.slash", tint: .secondary, floats: false,
                title: account.title,
                detail: account == .restricted
                    ? "스크린 타임이나 기기 관리 설정에서 iCloud 사용이 막혀 있어요. 다른 기기의 기록은 불러올 수 없지만, \(Platform.thisDevice)에만 기록하며 사용할 수 있어요."
                    : "다른 기기의 기록을 불러오려면 기기의 설정에서 iCloud에 로그인해 주세요. 로그인하지 않아도 \(Platform.thisDevice)에만 기록하며 사용할 수 있어요."
            ) {
                choices
            }
        case .stalled(let note):
            message(
                badge: "exclamationmark.icloud", tint: Theme.streakTint, floats: false,
                title: "동기화가 오래 걸리고 있어요",
                detail: "아직 기록을 다 확인하지 못했어요. 네트워크 연결을 확인해 주세요. 일단 시작해도 다른 기기의 기록은 도착하는 대로 나타나고, 그사이 적은 내용도 그대로 남아요."
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

    /// 가운데의 새싹이, 제목, 설명, 그 아래의 내용. `badge`는 문제가 있을 때 새싹이 옆에 붙이는 상태 아이콘이다.
    private func message(
        badge: String?, tint: Color, floats: Bool, pose: SaessagiPose = .idle, title: String, detail: String,
        @ViewBuilder footer: () -> some View
    ) -> some View {
        VStack(spacing: 18) {
            // 기다리는 동안에는 두리번거리고, 문제가 생겨 멈춘 화면에서는 숨 쉬고 깜빡이기만 한다. 다 받은 순간은 기뻐서 뛴다.
            SaessagiAnimatedView(pose: pose, size: 132, behavior: pose == .idle ? (floats ? .waiting : .calm) : .celebrating)
                .padding(22)
                .background(Theme.accent.opacity(0.12), in: Circle())
                .overlay(alignment: .bottomTrailing) {
                    if let badge {
                        Image(systemName: badge)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(tint)
                            .frame(width: 40, height: 40)
                            .background(Theme.cardBackground, in: Circle())
                            .overlay(Circle().strokeBorder(Theme.cardBorder, lineWidth: 1))
                            .accessibilityHidden(true)
                    }
                }
            VStack(spacing: 8) {
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
            .padding(.top, 6)
        }
    }

    /// 기다리지 않아도 되는 두 가지 길. 어느 쪽도 기록을 지우거나 바꾸지 않는다.
    private var choices: some View {
        VStack(spacing: 10) {
            Button(action: { if preview == nil { gate.finish() } }) {
                Text("일단 시작하기").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("시작 안내로 넘어갑니다. 다른 기기의 기록이 나중에 오면 그대로 합쳐져요.")
            Button(action: { if preview == nil { recheck() } }) {
                Text(isRechecking ? "확인 중…" : "다시 확인").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isRechecking)
        }
        .controlSize(.large)
        .frame(maxWidth: 300)
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
