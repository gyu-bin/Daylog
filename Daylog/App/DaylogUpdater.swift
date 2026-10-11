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
    private var controller: SPUStandardUpdaterController?
    private var observation: AnyCancellable?

    private init() {
        guard !RuntimeEnvironment.isRunningTests,
              UpdateConfiguration(info: Bundle.main.infoDictionary ?? [:]).isReady else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
        )
        self.controller = controller
        observation = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
        controller.startUpdater()
    }

    var isConfigured: Bool { controller != nil }

    func checkForUpdates() {
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = "자동 업데이트 준비 중"
            alert.informativeText = "이 버전은 앱 안에서 업데이트를 받을 수 없어요. 업데이트 배포가 준비되면 사용할 수 있습니다."
            alert.addButton(withTitle: "확인")
            alert.runModal()
            return
        }
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }
}

struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = DaylogUpdater.shared

    var body: some View {
        Button("업데이트 확인…") { updater.checkForUpdates() }
            .disabled(updater.isConfigured && !updater.canCheckForUpdates)
    }
}
#endif
