#if os(macOS)
import AppKit
import Combine
import Sparkle
import SwiftUI

/// The updater remains dormant until the release owner configures and approves it.
@MainActor
final class DaylogUpdater: ObservableObject {
    static let shared = DaylogUpdater()
    @Published private(set) var canCheckForUpdates = false
    /// 마지막 확인의 결과와 시각. 설정의 앱 정보가 보여 준다.
    @Published private(set) var lastOutcome: UpdateCheckOutcome?
    @Published private(set) var lastCheckedAt: Date?
    private var controller: SPUStandardUpdaterController?
    private var observation: AnyCancellable?
    private let events = UpdaterEvents()

    private init() {
        guard !RuntimeEnvironment.isRunningTests,
              UpdateConfiguration(info: Bundle.main.infoDictionary ?? [:]).isReady else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: events, userDriverDelegate: nil
        )
        self.controller = controller
        events.onFinish = { [weak self] outcome in
            self?.lastCheckedAt = .now
            // 취소처럼 알릴 것이 없는 끝맺음은 앞의 결과를 지우지 않는다.
            if let outcome { self?.lastOutcome = outcome }
        }
        observation = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
        controller.startUpdater()
    }

    var isConfigured: Bool { controller != nil }

    /// 메뉴와 설정의 [업데이트 확인]이 함께 쓴다. 새 버전·변경 사항·설치 승인·오류 창은 Sparkle이 띄운다.
    func checkForUpdates() {
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = "자동 업데이트 준비 중"
            alert.informativeText = "이 버전은 앱 안에서 업데이트를 받을 수 없어요. 새 버전은 GitHub 릴리스 페이지에서 받을 수 있습니다."
            alert.addButton(withTitle: "릴리스 페이지 열기")
            alert.addButton(withTitle: "확인")
            if alert.runModal() == .alertFirstButtonReturn { openReleasesPage() }
            return
        }
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }

    func openReleasesPage() {
        if let url = UpdateCheckOutcome.releasesPage { NSWorkspace.shared.open(url) }
    }
}

/// Sparkle이 알려 주는 확인 과정을 한 번의 결과로 모은다.
private final class UpdaterEvents: NSObject, SPUUpdaterDelegate {
    var onFinish: (@MainActor (UpdateCheckOutcome?) -> Void)?
    private var foundVersion: String?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        foundVersion = item.displayVersionString
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let nsError = error.map { $0 as NSError }
        let outcome = UpdateCheckOutcome.resolve(
            foundVersion: foundVersion, errorDomain: nsError?.domain, errorCode: nsError?.code,
            errorMessage: nsError?.localizedDescription
        )
        foundVersion = nil
        let onFinish = onFinish
        Task { @MainActor in onFinish?(outcome) }
    }
}

struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = DaylogUpdater.shared

    var body: some View {
        Button("업데이트 확인…") { updater.checkForUpdates() }
            .disabled(updater.isConfigured && !updater.canCheckForUpdates)
    }
}

/// 설정 → 앱 정보의 업데이트 줄: 지금 상태 한 줄과 [업데이트 확인]. 준비 전에는 릴리스 페이지로 안내한다.
struct UpdateSettingsRow: View {
    @ObservedObject private var updater = DaylogUpdater.shared
    let currentVersion: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("업데이트")
                Text(UpdateCheckOutcome.statusText(
                    isConfigured: updater.isConfigured, outcome: updater.lastOutcome, currentVersion: currentVersion
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if let checkedAt = updater.lastCheckedAt {
                    Text("마지막 확인 \(checkedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 12)
            if updater.isConfigured {
                CheckForUpdatesButton()
            } else {
                Button("릴리스 페이지 열기") { updater.openReleasesPage() }
                    .accessibilityHint("브라우저에서 GitHub의 최신 릴리스를 엽니다.")
            }
        }
        .padding(.vertical, 2)
    }
}
#endif
