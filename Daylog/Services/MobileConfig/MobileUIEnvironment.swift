import SwiftUI

private struct MobileUIKey: EnvironmentKey {
    static let defaultValue = MobileUISettings.builtIn
}

extension EnvironmentValues {
    /// 원격 설정이 반영된 화면 값. iPhone·iPad에서만 화면의 뿌리가 넣어 주고, macOS에서는 늘 내장 기본값이다.
    var mobileUI: MobileUISettings {
        get { self[MobileUIKey.self] }
        set { self[MobileUIKey.self] = newValue }
    }
}

/// 카드의 바탕과 테두리. 원격 설정의 카드 스타일(미리 만들어 둔 세 가지)에 따라 달라진다.
struct CardChrome<S: InsettableShape>: ViewModifier {
    @Environment(\.mobileUI) private var ui
    let shape: S

    func body(content: Content) -> some View {
        switch ui.cardStyle {
        case .bordered:
            content
                .background(Theme.cardBackground, in: shape)
                .overlay(shape.strokeBorder(Theme.cardBorder, lineWidth: 1))
        case .soft:
            content
                .background(Theme.cardBackground, in: shape)
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        case .flat:
            content
                .background(Theme.cardBackground, in: shape)
        }
    }
}

extension View {
    /// 카드의 바탕과 테두리를 입힌다(카드 스타일 설정을 따른다).
    func cardChrome<S: InsettableShape>(_ shape: S) -> some View {
        modifier(CardChrome(shape: shape))
    }
}
