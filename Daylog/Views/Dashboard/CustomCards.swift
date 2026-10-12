import SwiftUI

/// 사용자가 더한 꾸미기 카드 한 장. 기능 카드(루틴·식사·통계)와 달리 기록을 다루지 않는다.
struct CustomCardView: View {
    @Environment(AppStore.self) private var store
    @Environment(DashboardDecor.self) private var decor
    let kind: CustomCardKind
    let id: UUID
    /// 좁은 화면(iPhone). 사진과 글이 화면을 밀어내지 않게 한 단계 낮춘다.
    let compact: Bool
    /// 사진이 없을 때 눌러서 편집을 연다.
    var onEdit: () -> Void = {}

    var body: some View {
        let entry = decor.entry(id)
        switch kind {
        case .image:
            if let image = decor.image(for: id) {
                DashboardImageSurface(image: image, height: entry.size.imageHeight(compact: compact), caption: entry.title, size: entry.size)
            } else {
                ImagePlaceholder(isBroken: entry.imageFile != nil, action: onEdit)
            }
        case .text:
            TextNoteCard(text: store.dashboardTexts[id] ?? DashboardText(title: "", body: ""), size: entry.size, compact: compact)
        case .sectionTitle:
            Text(entry.title.isEmpty ? "섹션 제목" : entry.title)
                .font(Self.sectionFont(entry.size))
                .foregroundStyle(entry.title.isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
        case .divider:
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Self.dividerPadding(entry.size))
                .accessibilityHidden(true)
        }
    }

    static func sectionFont(_ size: CustomCardSize) -> Font {
        switch size {
        case .small: return .headline
        case .regular: return .title3.weight(.semibold)
        case .large: return .title2.weight(.bold)
        }
    }

    static func dividerPadding(_ size: CustomCardSize) -> CGFloat {
        switch size {
        case .small: return 2
        case .regular: return 8
        case .large: return 16
        }
    }
}

/// 정해진 높이에 사진을 채워 넣는다(가운데 기준으로 잘린다). 문구는 어두운 그늘 위에 흰 글자로 올려, 밝은 사진에서도 읽힌다.
struct DashboardImageSurface: View {
    let image: CGImage
    let height: CGFloat
    var caption = ""
    var size: CustomCardSize = .regular

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        // 사진의 크기가 배치를 밀어내지 않게, 빈 면에 덧그리고 잘라 낸다.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                // 채워 넣은 사진은 틀 밖으로 넘친다. 잘라 내도 누르기 영역은 남으므로, 사진이 이웃한 카드의 누르기를 가로채지 않게 끈다.
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                if !caption.isEmpty {
                    Text(caption)
                        .font(size == .small ? .callout.weight(.semibold) : .headline)
                        .foregroundStyle(.white)
                        .lineLimit(size == .large ? 2 : 1)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.black.opacity(0), .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                }
            }
            .clipShape(shape)
            .contentShape(shape)
            .overlay(shape.strokeBorder(Theme.cardBorder, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(caption.isEmpty ? "꾸미기 사진" : "꾸미기 사진, \(caption)")
            .accessibilityAddTraits(.isImage)
    }
}

/// 사진을 아직 고르지 않았거나, 저장해 둔 사진을 읽을 수 없을 때.
private struct ImagePlaceholder: View {
    let isBroken: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isBroken ? "exclamationmark.triangle" : "photo")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isBroken ? AnyShapeStyle(GroupColor.orange.ink) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isBroken ? "사진을 불러올 수 없어요" : "사진이 아직 없어요")
                        .font(.callout.weight(.semibold))
                    Text(isBroken ? "파일이 없거나 손상됐어요. 눌러서 다시 골라 주세요." : "눌러서 사진을 골라 주세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Theme.inset, in: shape)
            .overlay(shape.strokeBorder(Theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("사진을 고르는 화면을 엽니다.")
    }
}

/// 목표·다짐·메모를 적는 카드. 왼쪽의 색 띠로 기능 카드와 구분한다.
private struct TextNoteCard: View {
    let text: DashboardText
    let size: CustomCardSize
    let compact: Bool

    /// 긴 글이 화면을 차지하지 않게 줄 수를 제한한다(전체 글은 편집에서 본다).
    private var lineLimit: Int {
        switch size {
        case .small: return 3
        case .regular: return compact ? 5 : 6
        case .large: return compact ? 8 : 12
        }
    }

    var body: some View {
        Card(fillsHeight: false) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    if !text.title.isEmpty {
                        Text(text.title)
                            .font(size == .large ? .title3.weight(.semibold) : size == .small ? .callout.weight(.semibold) : .headline)
                            .lineLimit(2)
                    }
                    if !text.body.isEmpty {
                        Text(text.body)
                            .font(size == .large ? .body : .callout)
                            .foregroundStyle(text.title.isEmpty ? .primary : .secondary)
                            .lineLimit(lineLimit)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if text.isEmpty {
                        Text("내용이 없어요").font(.callout).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 머리말(날짜·인사말) 뒤에 까는 낮은 배경 사진. 사진이 없으면 머리말은 예전 그대로다.
/// 머리말의 높이만큼만 차지하므로 첫 카드가 거의 밀리지 않는다. 사진 위에는 창 바탕색을 한 겹 덮어 글자가 라이트·다크 모두에서 읽힌다.
struct DashboardHeaderBackdrop: ViewModifier {
    @Environment(DashboardDecor.self) private var decor
    /// 사진이 있을 때 머리말 둘레에 두는 여백.
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        if let image = decor.headerImage {
            let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    Color.clear
                        .overlay {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .scaledToFill()
                                .allowsHitTesting(false)
                        }
                        .overlay(
                            LinearGradient(
                                colors: [Theme.windowBackground.opacity(0.86), Theme.windowBackground.opacity(0.5)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(shape)
                        .overlay(shape.strokeBorder(Theme.cardBorder, lineWidth: 1))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        } else {
            content
        }
    }
}

extension View {
    func dashboardHeaderBackdrop(padding: CGFloat = 14) -> some View {
        modifier(DashboardHeaderBackdrop(padding: padding))
    }
}
