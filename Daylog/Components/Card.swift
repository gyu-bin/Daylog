import SwiftUI

/// 화면의 기본 컨테이너. 시스템 배경색 + 아주 옅은 경계, 그림자 없음.
struct Card<Content: View>: View {
    /// 옆 카드와 높이를 맞춰 늘어날지 여부. false면 내용만큼만 차지한다.
    var fillsHeight = true
    var padding: CGFloat = Theme.cardPadding
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
            .background(Theme.cardBackground, in: shape)
            .overlay(shape.strokeBorder(Theme.cardBorder, lineWidth: 1))
    }
}

/// 카드·섹션의 머리말: 색 있는 아이콘 + 제목 + (부제) + 오른쪽 컨트롤.
struct CardHeader<Trailing: View>: View {
    let symbol: String
    let title: String
    var subtitle: String?
    var tint: Color = Theme.accent
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
    init(symbol: String, title: String, subtitle: String? = nil, tint: Color = Theme.accent) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, tint: tint, trailing: { EmptyView() })
    }
}

/// 빈 상태 안내: 작은 아이콘, 한두 줄 설명, 필요하면 다음 행동 버튼.
struct EmptyHint: View {
    let symbol: String
    let message: String
    var tint: Color = .secondary
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
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

/// 작은 상태 배지("보관됨", "삭제됨" 등). 색과 함께 글자로 상태를 전한다.
struct StatusBadge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

/// 통계 요약 한 칸: 색 있는 아이콘과 제목, 큰 숫자, 한 줄 설명. 높이가 모두 같다.
struct StatTile<Accessory: View>: View {
    let symbol: String
    let title: String
    let color: GroupColor
    /// 표시할 값. 아직 값이 없으면 nil.
    let value: String?
    var unit: String = ""
    let caption: String
    /// 좁은 칸(iPhone의 두 열)용. 여백과 숫자를 줄이고, 글자가 칸 너비를 넘기지 않게 줄바꿈·축소를 허용한다.
    var isCompact = false
    @ViewBuilder var accessory: () -> Accessory

    /// 좁은 칸의 숫자 크기. 큰 글씨 설정을 따라 커진다.
    @ScaledMetric(relativeTo: .title2) private var compactValueSize: CGFloat = 26

    var body: some View {
        Card(padding: isCompact ? 12 : 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: isCompact ? .top : .center, spacing: 7) {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color.color)
                        .frame(width: 22, height: 22)
                        .background(color.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        // 좁은 칸에서는 긴 제목을 자르지 않고 두 줄까지 쓴다.
                        .lineLimit(isCompact ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: isCompact)
                }
                Spacer(minLength: 6)
                if let value {
                    HStack(alignment: .center, spacing: isCompact ? 8 : 10) {
                        valueText(value)
                        Spacer(minLength: 0)
                        accessory()
                    }
                    Spacer(minLength: 6)
                }
                // 값이 없을 때는 설명이 그 자리를 대신한다.
                Text(caption)
                    .font(value == nil ? .callout : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(value == nil || isCompact ? 2 : 1)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                if value == nil {
                    Spacer(minLength: 0)
                }
            }
        }
        // 좁은 칸은 글자 크기에 따라 높이가 자란다(같은 줄의 칸끼리는 격자가 높이를 맞춘다).
        .frame(minHeight: isCompact ? Theme.statCardHeight - 14 : Theme.statCardHeight,
               maxHeight: isCompact ? nil : Theme.statCardHeight)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func valueText(_ value: String) -> some View {
        let text = HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: isCompact ? compactValueSize : 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            if !unit.isEmpty {
                Text(unit).font(.system(size: isCompact ? compactValueSize * 0.55 : 16, weight: .semibold))
            }
        }
        // 큰 숫자는 아이콘 색보다 한 단계 진한 색으로 써서 밝은 배경에서도 읽히게 한다.
        .foregroundStyle(color.ink)
        .lineLimit(1)
        if isCompact {
            // 칸을 밀어내지 않는다: 자리가 모자라면 숫자를 줄인다(자르지 않는다).
            text.minimumScaleFactor(0.6).layoutPriority(1)
        } else {
            text.fixedSize()
        }
    }
}

extension StatTile where Accessory == EmptyView {
    init(
        symbol: String, title: String, color: GroupColor, value: String?, unit: String = "", caption: String, isCompact: Bool = false
    ) {
        self.init(
            symbol: symbol, title: title, color: color, value: value, unit: unit, caption: caption, isCompact: isCompact,
            accessory: { EmptyView() }
        )
    }
}
