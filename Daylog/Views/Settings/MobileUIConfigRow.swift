#if os(iOS)
import SwiftUI

/// 설정 → 정보의 "UI 설정" 줄(iPhone·iPad): 지금 쓰는 표시 설정의 버전, 마지막 확인 시각, [UI 설정 새로고침].
/// 앱 버전 업데이트와는 다르다. 화면 배치·문구 같은 표시 설정만 받고, 앱의 기능이나 기록은 바뀌지 않는다.
struct MobileUIConfigRow: View {
    @Environment(MobileUIConfigStore.self) private var config

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("UI 설정", value: config.versionText)
            if let checkedAt = config.lastCheckedAt {
                LabeledContent("마지막 확인") {
                    Text(checkedAt, format: .dateTime.month().day().hour().minute())
                        .monospacedDigit()
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            if let text = config.outcomeText {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if config.accentChangesOnRelaunch {
                Text("강조 색은 앱을 다시 열면 바뀌어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await config.refreshNow() }
            } label: {
                if config.isRefreshing {
                    Label("확인하는 중…", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Label("UI 설정 새로고침", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(config.isRefreshing)
            .accessibilityHint("화면 배치와 문구 같은 표시 설정을 새로 받습니다. 앱 버전은 바뀌지 않습니다.")
            Text("화면 배치·문구 같은 표시 설정만 받아요. 앱 버전이나 기능, 기록은 바뀌지 않아요.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}
#endif
