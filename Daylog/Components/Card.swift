import SwiftUI

/// 대시보드의 기본 컨테이너. 시스템 배경색 + 얇은 경계, 그림자 없음.
struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
    }

    var body: some View {
        content()
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.cardBackground, in: shape)
            .overlay(shape.strokeBorder(Theme.separator, lineWidth: 1))
    }
}

struct CardHeader<Trailing: View>: View {
    let symbol: String
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
                .accessibilityHidden(true)
            // 좁아지면 부제부터 줄이고, 제목과 오른쪽 컨트롤은 온전히 남긴다.
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .layoutPriority(2)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            trailing()
                .fixedSize()
                .layoutPriority(1)
        }
        .accessibilityElement(children: .contain)
    }
}

extension CardHeader where Trailing == EmptyView {
    init(symbol: String, title: String, subtitle: String? = nil) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// 카드 안의 빈 상태 안내.
struct EmptyHint: View {
    let symbol: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 18)
    }
}

/// "전체 보기 >" 같은 카드 머리말의 이동 링크.
struct HeaderLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
