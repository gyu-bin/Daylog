import SwiftUI

/// 템플릿 메뉴: 공식 루틴 템플릿을 분류와 검색으로 찾아 보고, 눌러서 미리 본 뒤 가져온다.
/// macOS·iPad는 사이드바의 메뉴로, iPhone은 루틴 탭의 [템플릿] 단추가 띄우는 시트로 들어온다.
struct TemplateLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(CommunityStore.self) private var community
    /// 앱에 든 공식 템플릿. 서버와 무관하게 늘 있다.
    var official = TemplateCatalog.official
    /// 시트로 띄웠을 때 닫는 동작. 메뉴로 들어왔으면 nil.
    var onClose: (() -> Void)? = nil

    @State private var query = ""
    /// 고른 분류. nil이면 전체.
    @State private var category: TemplateCategory?
    @State private var selected: RoutineTemplate?
    @State private var publishes = false
    @State private var managesMine = false
    @State private var shares = false
    @State private var importsFile = false
    /// 파일에서 읽은 템플릿(미리보기로 띄운다)과 읽지 못한 까닭.
    @State private var fileTemplate: RoutineTemplate?
    @State private var fileError: String?

    /// 공식 템플릿 뒤에 공개 템플릿을 잇는다. 공개 템플릿을 받지 못해도 공식 템플릿은 그대로 나온다.
    private var catalog: TemplateCatalog {
        TemplateCatalog(templates: official.templates + community.catalogTemplates)
    }

    private var results: [RoutineTemplate] { catalog.filtered(category: category, query: query) }

    var body: some View {
        let results = results
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    PageTitle(
                        title: "템플릿",
                        subtitle: community.isAvailable
                            ? "공식 템플릿과 다른 사람이 올린 템플릿을 미리 보고, 필요한 것만 내 RoutiMori에 추가해요."
                            : "공식 루틴 템플릿을 미리 보고, 필요한 것만 내 RoutiMori에 추가해요."
                    )
                    Spacer(minLength: 8)
                    if let onClose {
                        Button("닫기", action: onClose)
                            .buttonStyle(.bordered)
                            .fixedSize()
                    }
                }
                fileBar
                if community.isAvailable { communityBar }
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
        .task { await community.refreshIfNeeded() }
        .sheet(isPresented: $shares) { TemplateShareSheet() }
        .sheet(item: $fileTemplate) { template in
            TemplateDetailSheet(template: template) {
                fileTemplate = nil
                if let onClose { onClose() } else { store.leaveSheet(to: .routines) }
            }
        }
        .fileImporter(isPresented: $importsFile, allowedContentTypes: [.daylogTemplate, .json]) { result in
            do {
                fileTemplate = try TemplateFile.read(try result.get())
                fileError = nil
            } catch {
                fileError = error.localizedDescription
            }
        }
        .alert("템플릿 파일을 열 수 없어요", isPresented: Binding(get: { fileError != nil }, set: { if !$0 { fileError = nil } })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(fileError ?? "")
        }
        .sheet(isPresented: $publishes) { TemplatePublishSheet(editing: nil) }
        .sheet(isPresented: $managesMine) { MyTemplatesSheet() }
        .sheet(item: $selected) { template in
            TemplateDetailSheet(template: template) {
                // 가져온 루틴을 보러 간다: 시트로 떠 있었으면 닫고(루틴 탭 위에 떠 있다), 메뉴였으면 루틴 메뉴로.
                selected = nil
                if let onClose { onClose() } else { store.leaveSheet(to: .routines) }
            }
        }
    }

    /// 파일로 주고받기: 내 루틴을 템플릿 파일로 만들어 보내고, 받은 파일을 연다. 서버나 로그인이 필요 없다.
    private var fileBar: some View {
        FlowLayout(spacing: 8) {
            Button {
                shares = true
            } label: {
                Label("내 루틴 공유하기", systemImage: "square.and.arrow.up")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityHint("고른 루틴을 템플릿 파일로 만들어 공유합니다.")
            Button {
                importsFile = true
            } label: {
                Label("파일에서 가져오기", systemImage: "square.and.arrow.down")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityHint("받은 템플릿 파일을 열어 미리 봅니다.")
        }
    }

    /// 공유 관련 단추와 공개 템플릿을 받아 온 상태. 서버 설정이 있을 때만 나온다.
    private var communityBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                Button {
                    publishes = true
                } label: {
                    Label("내 템플릿 올리기", systemImage: "square.and.arrow.up")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                Button {
                    managesMine = true
                } label: {
                    Label("내 템플릿", systemImage: "person.crop.rectangle.stack")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.bordered)
                if community.isMock {
                    StatusBadge(text: "시험용 서버", tint: GroupColor.orange.ink)
                }
            }
            switch community.loadState {
            case .failed(let message):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("공개 템플릿을 불러오지 못했어요. \(message)", systemImage: "wifi.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("다시 시도") { Task { await community.refresh() } }
                        .controlSize(.small)
                }
            case .loading where community.publicTemplates.isEmpty:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("공개 템플릿을 불러오는 중…").font(.caption).foregroundStyle(.secondary)
                }
            default:
                EmptyView()
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
struct TemplateCard: View {
    let template: RoutineTemplate
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// "공식", "받은 파일" 또는 게시자 이름.
    static func sourceLabel(_ template: RoutineTemplate) -> String {
        switch template.source {
        case .official: return "공식"
        case .file: return "받은 파일"
        case .community: return template.author ?? "익명"
        }
    }

    var body: some View {
        let color = GroupColor(key: template.thumbnail.colorKey)
        // 큰 글자 크기: 제목·설명·출처가 "…"로 잘리지 않게 줄 수를 늘리고, 분류와 출처를 두 줄로 나눈다.
        let isLargeText = dynamicTypeSize.isAccessibilitySize
        let meta = Text("루틴 \(template.routineCount)개 · \(TemplateCard.sourceLabel(template))")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        let chevron = Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                TemplateThumbnailView(thumbnail: template.thumbnail)
                VStack(alignment: .leading, spacing: 5) {
                    Text(template.title)
                        .font(.headline)
                        .lineLimit(isLargeText ? 2 : 1)
                        .multilineTextAlignment(.leading)
                    Text(template.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(isLargeText ? 4 : 2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                    if isLargeText {
                        StatusBadge(text: template.category.title, tint: color.ink)
                        HStack(spacing: 6) {
                            meta.lineLimit(2)
                            Spacer(minLength: 0)
                            chevron
                        }
                    } else {
                        HStack(spacing: 6) {
                            StatusBadge(text: template.category.title, tint: color.ink)
                            meta.lineLimit(1)
                            Spacer(minLength: 0)
                            chevron
                        }
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
        .accessibilityLabel("\(template.title), \(template.category.title), 루틴 \(template.routineCount)개, \(Self.sourceLabel(template))")
        .accessibilityValue(template.summary)
        .accessibilityHint("눌러서 포함된 루틴을 미리 봅니다.")
    }
}
