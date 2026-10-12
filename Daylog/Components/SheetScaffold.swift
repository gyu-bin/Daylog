import SwiftUI

/// 시트의 주요 동작(저장·확인 같은 것).
struct SheetAction {
    var title: String
    var isDisabled = false
    var action: () -> Void
}

/// 모든 시트가 같은 틀을 쓴다: 제목과 한 줄 설명, 내용, 아래쪽의 [취소] [저장].
///
/// macOS: 가운데 뜨는 창으로, 높이는 내용만큼만 차지한다(고정 높이로 아래가 비지 않게). Esc = 취소, Return = 주요 동작.
/// iPhone·iPad: 탐색 막대의 제목과 좌우 단추를 쓰고, 내용은 스크롤된다.
struct SheetScaffold<Content: View, Leading: View>: View {
    let title: String
    var subtitle: String?
    /// macOS 시트의 너비.
    var width: CGFloat = 460
    var cancelTitle = "취소"
    let cancel: () -> Void
    var primary: SheetAction?
    /// 아래쪽 왼편에 두는 보조 동작(삭제·해제처럼 주요 동작과 떨어뜨려 둘 것).
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var content: () -> Content

    init(
        title: String, subtitle: String? = nil, width: CGFloat = 460, cancelTitle: String = "취소",
        cancel: @escaping () -> Void, primary: SheetAction? = nil,
        @ViewBuilder leading: @escaping () -> Leading, @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.width = width
        self.cancelTitle = cancelTitle
        self.cancel = cancel
        self.primary = primary
        self.leading = leading
        self.content = content
    }

    var body: some View {
        #if os(macOS)
        macSheet
        #else
        touchSheet
        #endif
    }

    #if os(macOS)
    private var macSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                CloseButton(action: cancel)
            }
            .padding(.bottom, 18)

            content()

            HStack(spacing: 8) {
                leading()
                Spacer(minLength: 8)
                Button(cancelTitle, action: cancel)
                    .keyboardShortcut(.cancelAction)
                if let primary {
                    Button(primary.title, action: primary.action)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(primary.isDisabled)
                }
            }
            .controlSize(.large)
            .padding(.top, 20)
        }
        .padding(Theme.sheetPadding)
        .frame(width: width)
    }
    #else
    private var touchSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    content()
                    leading()
                }
                .padding(20)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneBar()
            .background(Theme.windowBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle, action: cancel)
                }
                if let primary {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(primary.title, action: primary.action)
                            .disabled(primary.isDisabled)
                    }
                }
            }
        }
    }
    #endif
}

extension SheetScaffold where Leading == EmptyView {
    init(
        title: String, subtitle: String? = nil, width: CGFloat = 460, cancelTitle: String = "취소",
        cancel: @escaping () -> Void, primary: SheetAction? = nil, @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title, subtitle: subtitle, width: width, cancelTitle: cancelTitle, cancel: cancel, primary: primary,
            leading: { EmptyView() }, content: content
        )
    }
}

/// 시트 오른쪽 위의 둥근 닫기 단추(macOS).
struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(isHovered ? Color.primary.opacity(0.14) : Theme.track, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("닫기")
        .help("저장하지 않고 닫기")
    }
}

/// 시트 안의 입력 묶음: 작은 제목 + 내용.
struct SheetField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            content()
        }
    }
}

/// 시트 안의 안내문: 아이콘과 한두 줄 설명.
struct SheetNote: View {
    let symbol: String
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
        }
    }
}
