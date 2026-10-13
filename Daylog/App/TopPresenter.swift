#if os(iOS)
import SwiftUI
import UIKit

/// 지금 맨 위에 떠 있는 화면 위에 시트나 알림을 올린다(iPhone·iPad).
/// 다른 앱이 넘겨준 파일은 Daylog가 어떤 화면을 보여 주고 있든 들어오므로, SwiftUI의 한 화면에 묶인 시트로는 놓칠 수 있다.
@MainActor
enum TopPresenter {
    /// 닫히는 중인 화면(방금 끝난 공유 시트 등)이 물러난 뒤에 올리도록 잠깐 기다린다.
    private static let settleDelay: Duration = .milliseconds(500)

    static func present<Content: View>(@ViewBuilder _ content: @escaping () -> Content) {
        Task {
            try? await Task.sleep(for: settleDelay)
            guard let top = topController() else { return }
            let host = UIHostingController(rootView: content())
            host.modalPresentationStyle = .pageSheet
            top.present(host, animated: true)
        }
    }

    static func alert(title: String, message: String) {
        Task {
            try? await Task.sleep(for: settleDelay)
            guard let top = topController() else { return }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .cancel))
            top.present(alert, animated: true)
        }
    }

    /// 떠 있는 시트를 모두 닫는다.
    static func dismissAll() {
        rootController()?.dismiss(animated: true)
    }

    private static func rootController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return (scene?.keyWindow ?? scene?.windows.first)?.rootViewController
    }

    private static func topController() -> UIViewController? {
        var top = rootController()
        while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
}
#endif
