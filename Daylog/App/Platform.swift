import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// macOS와 iOS·iPadOS에서 이름이 다른 것들을 한곳에 모은다. 화면과 서비스는 이 이름만 쓴다.
enum Platform {
    /// "1.5.1 (1)" 같은 앱 버전.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "—") (\(info?["CFBundleVersion"] as? String ?? "—"))"
    }

    #if os(macOS)
    static let didBecomeActive = NSApplication.didBecomeActiveNotification
    static let willResignActive = NSApplication.willResignActiveNotification
    static let willTerminate = NSApplication.willTerminateNotification
    /// 잠자기에서 깨어났거나 시계가 크게 바뀐 시점.
    static var timeMayHaveJumped: NotificationCenter.Publisher {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
    }
    static let thisDevice = "이 Mac"
    static let isPhone = false
    /// iCloud 기기 목록에 적는 이름과 종류.
    static var deviceName: String { Host.current().localizedName ?? "Mac" }
    static let deviceKind = DeviceInfo.Kind.mac

    /// 창에 시트(편집 시트, 확인 창)가 붙어 있는가.
    @MainActor
    static var isShowingSheet: Bool {
        NSApp.windows.contains { $0.attachedSheet != nil }
    }

    /// 시스템 설정의 알림 화면을 연다.
    @MainActor
    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    #else
    static let didBecomeActive = UIApplication.didBecomeActiveNotification
    static let willResignActive = UIApplication.willResignActiveNotification
    static let willTerminate = UIApplication.willTerminateNotification
    static var timeMayHaveJumped: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
    }
    static var thisDevice: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "이 iPad" : "이 iPhone"
    }
    static var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    /// iCloud 기기 목록에 적는 이름과 종류. iOS는 사용자가 지은 기기 이름을 앱에 주지 않아 "iPhone"·"iPad"로 나온다.
    static var deviceName: String { UIDevice.current.name }
    static var deviceKind: DeviceInfo.Kind { UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone }

    /// 어느 창에든 시트가 떠 있는가. iPad는 창을 여러 개 열 수 있고 모든 창이 같은 화면 선택을 따르므로,
    /// 누른 창이 아니라 다른 창의 시트도 본다.
    @MainActor
    static var isShowingSheet: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { $0.rootViewController?.presentedViewController != nil }
    }

    /// 설정 앱에서 Daylog의 알림 화면을 연다.
    @MainActor
    static func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    #endif
}

extension Color {
    /// 화면 바탕, 카드 바탕, 구분선. 각 플랫폼의 시스템 색을 쓴다.
    static var platformWindowBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var platformCardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    static var platformSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
}
