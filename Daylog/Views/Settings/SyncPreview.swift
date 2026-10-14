import SwiftUI

/// 설정 > iCloud의 [동기화 화면 미리보기]: 새 기기에서 처음 열 때 보이는 첫 동기화 안내(`FirstSyncView`)를 세 가지 예시 장면으로 보여 준다.
///
/// 실제 동기화 상태(`CloudSyncMonitor`)는 읽지도 바꾸지도 않는다: 화면에 예시 상태를 넣어 그리기만 하고, 안의 단추는 아무 일도 하지 않는다.
/// 진행률은 CloudKit이 알려 주지 않아 실제 화면에도 없고, 미리보기에도 만들지 않는다.
struct SyncPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sample: SyncPreviewSample = Self.initialSample.sample
    /// 연결 문제에서 보여 줄 실제 상태(기본은 오래 걸림). 화면 검증용으로 오류·로그인 안 됨도 볼 수 있다(Debug 빌드만).
    private let troublePhase: FirstSyncPhase = Self.initialSample.trouble
    /// 미리보기 전용 안내 상태. 앱 전체가 함께 보는 실제 안내(`FirstSyncGate.shared`)와 상관없다.
    @State private var gate = FirstSyncGate()

    /// 처음 보여 줄 장면. 화면 검증용으로 `-DaylogDebugSyncSample ready`처럼 바꿀 수 있다(Debug 빌드만):
    /// receiving, ready, trouble, 그리고 연결 문제의 다른 경우 failed, noAccount.
    private static var initialSample: (sample: SyncPreviewSample, trouble: FirstSyncPhase) {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "DaylogDebugSyncSample") {
        case "ready": return (.ready, .stalled(nil))
        case "trouble": return (.trouble, .stalled(nil))
        case "failed": return (.trouble, .stalled("예시: 인터넷에 연결되어 있지 않아요."))
        case "noAccount": return (.trouble, .unavailable(.noAccount))
        default: break
        }
        #endif
        return (.receiving, .stalled(nil))
    }

    /// 미리보기 맨 위에 늘 보이는 안내.
    private var notice: some View {
        Label("예시 화면 · 실제 iCloud 상태가 아니에요.", systemImage: "eye")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.accentWash, in: Capsule())
    }

    private var exitButton: some View {
        Button("미리보기 종료") { dismiss() }
            .keyboardShortcut(.cancelAction)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // 좁은 화면(iPhone SE)에서는 안내가 두 줄로 꺾이지 않게 [미리보기 종료]를 윗줄로 올린다.
                ViewThatFits(in: .horizontal) {
                    HStack {
                        notice
                        Spacer(minLength: 8)
                        exitButton
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Spacer()
                            exitButton
                        }
                        notice
                    }
                }
                Picker("장면", selection: $sample) {
                    ForEach(SyncPreviewSample.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(16)
            .background(Theme.windowBackground)
            Divider()
            FirstSyncView(gate: gate, preview: sample.phase(trouble: troublePhase), previewNote: sample.note)
        }
        .background(Theme.windowBackground)
        #if os(macOS)
        .frame(width: 580, height: 820)
        #endif
    }
}

/// 미리보기에서 고를 수 있는 세 장면.
enum SyncPreviewSample: String, CaseIterable, Identifiable {
    case receiving, ready, trouble

    var id: String { rawValue }

    var title: String {
        switch self {
        case .receiving: return "기록 받는 중"
        case .ready: return "준비 완료"
        case .trouble: return "연결 문제"
        }
    }

    func phase(trouble: FirstSyncPhase = .stalled(nil)) -> FirstSyncPhase {
        switch self {
        case .receiving: return .waiting
        case .ready: return .found
        case .trouble: return trouble
        }
    }

    /// 그 장면이 실제로 언제 보이는지. 미리보기의 단추는 아무 일도 하지 않는다는 것도 함께 알린다.
    var note: String {
        let buttons = " 미리보기라 단추를 눌러도 아무 일도 일어나지 않아요."
        switch self {
        case .receiving:
            return "새 기기에서 처음 열면 다른 기기의 기록을 받는 동안 이 화면이 보여요. 받은 양은 iCloud가 알려 주지 않아 진행률은 없고, 내려오는 카드는 그림이에요."
        case .ready:
            return "실제로는 기록이 오는 순간 이 화면 없이 바로 오늘 화면으로 넘어가요. 미리보기에서만 보여 드려요." + buttons
        case .trouble:
            return "30초가 지나도 기록을 확인하지 못하거나 오류가 나면 보여요. iCloud에 로그인하지 않았으면 같은 그림에 로그인 안내가 나와요." + buttons
        }
    }
}
