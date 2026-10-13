import SwiftUI

/// 템플릿 메뉴: 공식 루틴 템플릿을 분류와 검색으로 찾아 보고, 눌러서 미리 본 뒤 가져온다.
/// macOS·iPad는 사이드바의 메뉴로, iPhone은 루틴 탭의 [템플릿] 단추가 띄우는 시트로 들어온다.
struct TemplateLibraryView: View {
    @Environment(AppStore.self) private var store
    var catalog = TemplateCatalog.official
    /// 시트로 띄웠을 때 닫는 동작. 메뉴로 들어왔으면 nil.
    var onClose: (() -> Void)? = nil

    @State private var query = ""
    /// 고른 분류. nil이면 전체.
    @State private var category: TemplateCategory?
    @State private var selected: RoutineTemplate?

    private var results: [RoutineTemplate] { catalog.filtered(category: category, query: query) }

    var body: some View {
        let results = results
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    PageTitle(title: "템플릿", subtitle: "공식 루틴 템플릿을 미리 보고, 필요한 것만 내 Daylog에 추가해요.")
                    Spacer(minLength: 8)
                    if let onClose {
                        Button("닫기", action: onClose)
                            .buttonStyle(.bordered)
                            .fixedSize()
                    }
                }
                searchField
                categoryBar

                if results.isEmpty {
                    Card(fillsHeight: false) {
                        EmptyHint(
                            symbol: "magnifyingglass", message: "조건에 맞는 템플릿이 없어요.\n검색어를 줄이거나 다른 분류를 골라 보세요.",
                            actionTitle: "전체 보기"
                        ) {
                            query = ""
                            category = nil
                        }
                    }
                } else {
                    Text("템플릿 \(results.count)개")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    // 화면 너비에 맞춰 한 줄에 1~3개. 카드 높이는 줄마다 맞춘다.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                        ForEach(results) { template in
                            TemplateCard(template: template) { selected = template }
                        }
                    }
                }
            }
            .pagePadding()
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.windowBackground)
        .sheet(item: $selected) { template in
            TemplateDetailSheet(template: template) {
                // 가져온 루틴을 보러 간다: 시트로 떠 있었으면 닫고(루틴 탭 위에 떠 있다), 메뉴였으면 루틴 메뉴로.
                selected = nil
                if let onClose { onClose() } else { store.section = .routines }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("템플릿 검색", text: $query, prompt: Text("제목·태그·루틴 이름으로 검색"))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .accessibilityLabel("템플릿 검색")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    /// 분류 고르기. 좁은 화면에서는 옆으로 민다.
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryChip("전체", value: nil)
                ForEach(catalog.categories) { item in
                    categoryChip(item.title, value: item)
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityLabel("분류")
    }

    private func categoryChip(_ title: String, value: TemplateCategory?) -> some View {
        let isSelected = category == value
        return Button {
            category = value
        } label: {
            Text(title)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.primary))
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.cardBackground), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.cardBorder, lineWidth: isSelected ? 0 : 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) 분류")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// 템플릿의 작은 그림: 색 바탕에 기호. 목록과 상세가 같은 그림을 크기만 달리 쓴다.
struct TemplateThumbnailView: View {
    let thumbnail: TemplateThumbnail
    var size: CGFloat = 44

    var body: some View {
        let color = GroupColor(key: thumbnail.colorKey)
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        Group {
            if let name = thumbnail.imageName {
                Image(name).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [color.color, color.color.opacity(0.68)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Image(systemName: thumbnail.symbol)
                            .font(.system(size: size * 0.44, weight: .semibold))
                            .foregroundStyle(Theme.onAccent)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

/// 목록의 템플릿 한 장: 작은 그림, 제목, 한 줄 설명, 분류와 루틴 수.
private struct TemplateCard: View {
    let template: RoutineTemplate
    let action: () -> Void

    var body: some View {
        let color = GroupColor(key: template.thumbnail.colorKey)
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                TemplateThumbnailView(thumbnail: template.thumbnail)
                VStack(alignment: .leading, spacing: 5) {
                    Text(template.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(template.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                    HStack(spacing: 6) {
                        StatusBadge(text: template.category.title, tint: color.ink)
                        Text("루틴 \(template.routineCount)개")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .cardChrome(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 버튼에 직접 이름을 붙인다(요소를 새로 만들면 누르기 동작이 사라진다).
        .accessibilityLabel("\(template.title), \(template.category.title), 루틴 \(template.routineCount)개")
        .accessibilityValue(template.summary)
        .accessibilityHint("눌러서 포함된 루틴을 미리 봅니다.")
    }
}
