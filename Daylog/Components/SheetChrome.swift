import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    /// 시트의 제목.
    /// macOS에서는 시트 안의 `navigationTitle`이 바깥 창의 제목까지 바꾸고 시트를 닫아도 그대로 남는다.
    /// 그래서 macOS에서는 제목을 시트 위쪽에 글자로 직접 그리고, 창 제목은 건드리지 않는다.
    @ViewBuilder
    func sheetTitle(_ title: String) -> some View {
        #if os(macOS)
        safeAreaInset(edge: .top, spacing: 0) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
        }
        #else
        navigationTitle(title)
        #endif
    }

    /// iPad의 창 모드(iPadOS 26 이상)에서는 창 왼쪽 위에 닫기·최소화·전체 화면 단추가 내용 위에 뜬다.
    /// 화면마다 왼쪽 위에 오는 제목·아이콘이 그 단추에 가려지므로, 창 모드일 때만 내용을 단추 높이만큼 내린다.
    /// (`containerCornerOffset`은 스크롤 영역 안의 제목에는 듣지 않았다. 탐색 막대를 쓰지 않는 화면이라 직접 비킨다.)
    @ViewBuilder
    func clearingWindowControls() -> some View {
        #if os(iOS)
        modifier(WindowControlsClearance())
        #else
        self
        #endif
    }

    /// 키보드가 올라와 있는 동안 그 위에 [완료] 단추를 둔다(iPhone·iPad).
    /// 여러 줄 입력칸은 Return이 줄바꿈이라 키보드를 내릴 방법이 따로 있어야 한다.
    /// `toolbar(.keyboard)`는 시트를 한 번 띄우고 나면 단추가 사라져서 쓰지 않는다. 시트마다 따로 붙인다.
    @ViewBuilder
    func keyboardDoneBar() -> some View {
        #if os(iOS)
        modifier(KeyboardDoneBar())
        #else
        self
        #endif
    }
}

/// 화면 키보드로 볼 최소 높이. 외장 키보드를 쓸 때 뜨는 낮은 보조 막대에는 [완료]를 띄우지 않는다.
enum KeyboardVisibility {
    static let minimumSoftwareKeyboardHeight: CGFloat = 120

    static func isSoftwareKeyboard(height: CGFloat) -> Bool {
        height >= minimumSoftwareKeyboardHeight
    }
}

/// iPad 창 모드에서 창 조절 단추가 차지하는 자리.
enum WindowControls {
    /// 단추 줄의 높이만큼 내용 위에 비울 여백.
    static let clearance: CGFloat = 26

    /// 창이 화면보다 작으면(창 모드) 창 조절 단추가 내용 위에 뜬다. 전체 화면에서는 상태 막대 쪽에 있어 가리지 않는다.
    /// iPadOS 26 이전에는 창 조절 단추가 없고, iPhone에는 창 모드가 없다.
    static func topClearance(window: CGSize, screen: CGSize, isPad: Bool, systemHasWindowControls: Bool) -> CGFloat {
        guard isPad, systemHasWindowControls else { return 0 }
        let isWindowed = window.width < screen.width - 1 || window.height < screen.height - 1
        return isWindowed ? clearance : 0
    }
}

#if os(iOS)
private struct WindowControlsClearance: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let window = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )
            // 안전 영역 여백은 탭 화면 안쪽까지 전달되지 않아서, 바깥에서 통째로 내린다.
            content
                .padding(.top, WindowControls.topClearance(
                    window: window, screen: UIScreen.main.bounds.size,
                    isPad: UIDevice.current.userInterfaceIdiom == .pad, systemHasWindowControls: Self.systemHasWindowControls
                ))
                .background(Theme.windowBackground)
        }
    }

    private static var systemHasWindowControls: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }
}

private struct KeyboardDoneBar: ViewModifier {
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isKeyboardVisible {
                    HStack {
                        Spacer()
                        Button("완료") {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                            )
                        }
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.cardBorder, lineWidth: 1))
                        .accessibilityLabel("키보드 닫기")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                isKeyboardVisible = KeyboardVisibility.isSoftwareKeyboard(height: frame.height)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
    }
}
#endif
