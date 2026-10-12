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
    /// 하루에 한 번쯤 스스로 새 버전을 확인할지. Sparkle이 이 Mac의 설정에 기억한다.
    @Published private(set) var checksAutomatically = false
    private var controller: SPUStandardUpdaterController?
    private var observation: AnyCancellable?
    private let events = UpdaterEvents()

    private init() {
        guard !RuntimeEnvironment.isRunningTests,
              UpdateConfiguration(
                  info: Bundle.main.infoDictionary ?? [:], bundleID: Bundle.main.bundleIdentifier ?? ""
              ).isReady else { return }
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
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
        lastCheckedAt = controller.updater.lastUpdateCheckDate
    }

    /// 자동 확인을 켜고 끈다. 끄면 [업데이트 확인]을 누를 때만 확인한다. 설치는 어느 쪽이든 사용자가 승인해야 한다.
    func setChecksAutomatically(_ isOn: Bool) {
        guard let controller else { return }
        controller.updater.automaticallyChecksForUpdates = isOn
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
    }

    var isConfigured: Bool { controller != nil }

    /// 메뉴와 설정의 [업데이트 확인]이 함께 쓴다. 새 버전·변경 사항·설치 승인·오류 창은 Sparkle이 띄운다.
    func checkForUpdates() {
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = "이 버전은 앱 안에서 업데이트할 수 없어요"
            alert.informativeText = "업데이트 기능이 들어간 버전을 GitHub 릴리스 페이지에서 한 번 받아 설치하면, 그다음부터는 앱 안에서 업데이트할 수 있습니다."
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

/// 설정 → 정보의 업데이트: 지금 상태 한 줄과 [업데이트 확인], 자동 확인 켜기/끄기.
/// 새 버전 안내·변경 사항·내려받기·설치·다시 열기는 Sparkle의 창이 맡는다.
/// 업데이트를 받을 수 없는 빌드(키가 없는 이전 배포판·개발 빌드)에서는 그 사실과 릴리스 페이지만 보여 준다.
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
                .foregroundStyle(isFailure ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
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
        if updater.isConfigured {
            Toggle(isOn: Binding(
                get: { updater.checksAutomatically },
                set: { updater.setChecksAutomatically($0) }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("자동으로 업데이트 확인")
                    Text("하루에 한 번쯤 GitHub에서 새 버전이 있는지만 확인해요. 설치는 직접 눌러야 시작돼요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var isFailure: Bool {
        if case .failed = updater.lastOutcome { return true }
        return false
    }
}
#endif
