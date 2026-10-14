import SwiftUI

/// 설정 > iCloud의 [동기화 화면 미리보기]: 새 기기에서 처음 열 때 보이는 첫 동기화 안내(`FirstSyncView`)를 예시 상태로 보여 준다.
///
/// 실제 동기화 상태(`CloudSyncMonitor`)는 읽지도 바꾸지도 않는다: 화면에 예시 상태를 넣어 그리기만 하고, 안의 단추는 아무 일도 하지 않는다.
/// 진행률은 CloudKit이 알려 주지 않아 실제 화면에도 없고, 미리보기에도 만들지 않는다.
struct SyncPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sample: SyncPreviewSample = Self.initialSample
    /// 미리보기 전용 안내 상태. 앱 전체가 함께 보는 실제 안내(`FirstSyncGate.shared`)와 상관없다.
    @State private var gate = FirstSyncGate()

    /// 처음 보여 줄 상태. 화면 검증용으로 `-DaylogDebugSyncSample failed`처럼 바꿀 수 있다(Debug 빌드만).
    private static var initialSample: SyncPreviewSample {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "DaylogDebugSyncSample"), let sample = SyncPreviewSample(rawValue: name) {
            return sample
        }
        #endif
        return .checking
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    Label("예시 화면 · 실제 iCloud 상태가 아니에요", systemImage: "eye")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accentWash, in: Capsule())
                    Spacer(minLength: 8)
                    Button("미리보기 종료") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                Picker("상태", selection: $sample) {
                    ForEach(SyncPreviewSample.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(sample.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            Divider()
            FirstSyncView(gate: gate, preview: sample.phase)
                .id(sample)
        }
        .background(Theme.windowBackground)
        #if os(macOS)
        .frame(width: 560, height: 720)
        #endif
    }
}

/// 미리보기에서 고를 수 있는 예시 상태.
enum SyncPreviewSample: String, CaseIterable, Identifiable {
    case checking, done, slow, failed, noAccount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checking: return "확인 중"
        case .done: return "완료"
        case .slow: return "지연"
        case .failed: return "오류"
        case .noAccount: return "iCloud 없음"
        }
    }

    var phase: FirstSyncPhase {
        switch self {
        case .checking: return .waiting
        case .done: return .found
        case .slow: return .stalled(nil)
        case .failed: return .stalled("예시: 인터넷에 연결되어 있지 않아요.")
        case .noAccount: return .unavailable(.noAccount)
        }
    }

    /// 그 상태가 실제로 언제 보이는지.
    var note: String {
        switch self {
        case .checking:
            return "새 기기에서 처음 열면 다른 기기의 기록을 받는 동안 이 화면이 보여요. 얼마나 받았는지는 iCloud가 알려 주지 않아 진행률은 없어요."
        case .done: return "기록이 오면 이 순간 바로 오늘 화면으로 넘어가요."
        case .slow: return "30초가 지나도 기록을 다 받지 못하면 기다리지 않고 먼저 시작할 수 있어요."
        case .failed: return "동기화 오류가 나면 내용을 알려 주고, 다시 확인하거나 먼저 시작할 수 있어요."
        case .noAccount: return "iCloud에 로그인하지 않았으면 이 기기에만 기록하며 쓸 수 있다고 알려 줘요."
        }
    }
}
