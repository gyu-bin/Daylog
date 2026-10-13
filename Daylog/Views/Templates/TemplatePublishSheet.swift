import SwiftUI

/// 내 루틴을 템플릿으로 올리거나, 올려 둔 템플릿을 고친다.
/// 게시할 그룹 → 제목·설명 → 분류·태그 → 썸네일 → 공개될 내용 확인 순서로 내려가고, 확인을 켜야 게시된다.
/// 올라가는 것은 화면 아래 "공개될 내용"에 보이는 것이 전부다. 게시물은 그 시점의 사본이라, 나중에 내 루틴을 바꿔도 따라 바뀌지 않는다.
struct TemplatePublishSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(CommunityStore.self) private var community
    @Environment(\.dismiss) private var dismiss
    /// 고칠 게시물. 새로 올릴 때는 nil.
    let editing: CommunityTemplate?

    @State private var sources: [TemplatePublishing.GroupSource] = []
    @State private var selected: Set<UUID> = []
    @State private var includesNotes = false
    /// 고칠 때: 올려 둔 구성을 그대로 둘지, 지금의 내 루틴으로 바꿀지.
    @State private var replacesContent = false
    @State private var title = ""
    @State private var summary = ""
    @State private var authorName = ""
    @State private var category = TemplateCategory.lifestyle
    @State private var tagsText = ""
    @State private var symbol = TemplatePublishing.symbols[0]
    @State private var colorKey = GroupColor.mint.rawValue
    @State private var isPublic = true
    @State private var confirmed = false
    @State private var showsRaw = false
    @State private var isWorking = false
    @State private var error: String?
    @State private var isLoaded = false

    private var usesStoredContent: Bool { editing != nil && !replacesContent }

    private var groups: [RoutineTemplate.Group] {
        if let editing, usesStoredContent { return editing.groups }
        return TemplatePublishing.groups(from: sources.filter { selected.contains($0.id) }, includesNotes: includesNotes)
    }

    private var draft: TemplateDraft {
        TemplateDraft(
            title: title, summary: summary, category: category,
            tags: tagsText.split(whereSeparator: { $0 == "," || $0 == "#" || $0.isNewline }).map(String.init),
            thumbnail: TemplateThumbnail(symbol: symbol, colorKey: colorKey), authorName: authorName,
            groups: groups, visibility: isPublic ? .public : .private
        ).cleaned
    }

    private var canSave: Bool {
        community.isSignedIn && !isWorking && draft.validationError == nil && (confirmed || !isPublic)
    }

    var body: some View {
        let draft = draft
        SheetScaffold(
            title: editing == nil ? "내 템플릿 올리기" : "템플릿 수정",
            subtitle: "루틴의 구성만 올라가요. 체크·식사·휴가 같은 기록은 올라가지 않아요.",
            width: 560, cancel: { dismiss() },
            primary: SheetAction(title: editing == nil ? "게시" : "저장", isDisabled: !canSave, action: save)
        ) {
            EmptyView()
        } content: {
            SheetScrollArea(maxHeight: 520) {
                VStack(alignment: .leading, spacing: 18) {
                    if !community.isSignedIn { CommunityAccountSection() }
                    groupSection
                    textSection
                    categorySection
                    thumbnailSection
                    previewSection(draft)
                    confirmSection(draft)
                }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: - 1. 그룹

    private var groupSection: some View {
        SheetField(label: "1. 게시할 그룹") {
            if editing != nil {
                Toggle("지금의 내 루틴으로 구성 바꾸기", isOn: $replacesContent)
                    .accessibilityHint("끄면 올려 둔 구성을 그대로 둡니다.")
            }
            if usesStoredContent {
                Text("올려 둔 구성을 그대로 둬요. 내 루틴을 바꿔도 게시물은 저절로 바뀌지 않아요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if sources.isEmpty {
                Text("올릴 수 있는 루틴이 없어요. 루틴 메뉴에서 그룹과 루틴을 먼저 만들어 주세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(sources) { source in
                        Toggle(isOn: Binding(
                            get: { selected.contains(source.id) },
                            set: { if $0 { selected.insert(source.id) } else { selected.remove(source.id) } }
                        )) {
                            HStack(spacing: 8) {
                                GroupBadge(title: source.title, color: GroupColor(key: source.colorKey), size: 20)
                                Text(source.title).lineLimit(1)
                                Text("루틴 \(source.routines.count)개")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .accessibilityLabel("\(source.title) 그룹, 루틴 \(source.routines.count)개")
                    }
                }
                .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                Toggle("루틴에 적어 둔 설명도 공개", isOn: $includesNotes)
                Text("끄면 루틴 이름·요일·시간만 올라가요. 설명에 개인적인 내용이 있으면 꺼 두세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 2. 제목과 설명

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetField(label: "2. 제목") {
                TextField("제목", text: $title, prompt: Text("예: 가볍게 시작하는 아침"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("템플릿 제목")
            }
            SheetField(label: "설명 (선택)") {
                TextField("설명", text: $summary, prompt: Text("어떤 사람에게 맞는 루틴인지 한두 문장으로"), axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("템플릿 설명, 선택 사항")
            }
            SheetField(label: "게시자 이름 (선택)") {
                TextField("게시자 이름", text: $authorName, prompt: Text("비워 두면 \"익명\"으로 보여요"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("게시자 이름, 선택 사항")
            }
        }
    }

    // MARK: - 3. 분류와 태그

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetField(label: "3. 분류") {
                FlowLayout(spacing: 6) {
                    ForEach(TemplateCategory.allCases) { item in
                        choiceChip(item.title, isSelected: category == item) { category = item }
                            .accessibilityLabel("\(item.title) 분류")
                    }
                }
            }
            SheetField(label: "태그 (선택, 쉼표로 구분)") {
                TextField("태그", text: $tagsText, prompt: Text("예: 아침, 스트레칭"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .accessibilityLabel("태그, 쉼표로 구분")
            }
        }
    }

    private func choiceChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.primary))
                .padding(.horizontal, 11)
                .frame(minHeight: 30)
                .background(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.inset), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 4. 썸네일

    private var thumbnailSection: some View {
        SheetField(label: "4. 썸네일") {
            HStack(alignment: .top, spacing: 12) {
                TemplateThumbnailView(thumbnail: TemplateThumbnail(symbol: symbol, colorKey: colorKey), size: 56)
                VStack(alignment: .leading, spacing: 8) {
                    FlowLayout(spacing: 6) {
                        ForEach(TemplatePublishing.symbols, id: \.self) { name in
                            Button {
                                symbol = name
                            } label: {
                                Image(systemName: name)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 32, height: 32)
                                    .background(symbol == name ? Theme.accentWash : Theme.inset, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(symbol == name ? Theme.accent : .clear, lineWidth: 1.5))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("기호 \(name)")
                            .accessibilityAddTraits(symbol == name ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(GroupColor.allCases, id: \.self) { color in
                            Button {
                                colorKey = color.rawValue
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(colorKey == color.rawValue ? 0.7 : 0), lineWidth: 2).padding(-3))
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(color.label) 색")
                            .accessibilityAddTraits(colorKey == color.rawValue ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. 공개될 내용

    private func previewSection(_ draft: TemplateDraft) -> some View {
        SheetField(label: "5. 공개될 내용") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    TemplateThumbnailView(thumbnail: draft.thumbnail, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.title.isEmpty ? "제목 없음" : draft.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(draft.title.isEmpty ? .secondary : .primary)
                        if !draft.summary.isEmpty {
                            Text(draft.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(draft.category.title) · 게시자 \(draft.authorName.isEmpty ? "익명" : draft.authorName)"
                            + (draft.tags.isEmpty ? "" : " · " + draft.tags.map { "#\($0)" }.joined(separator: " ")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if draft.groups.isEmpty {
                    Text("게시할 그룹을 골라 주세요.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(draft.groups.enumerated()), id: \.offset) { _, group in
                    TemplateGroupPreview(group: group)
                }
                DisclosureGroup("서버로 보내는 데이터 그대로 보기", isExpanded: $showsRaw) {
                    Text(TemplatePublishing.previewJSON(draft))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .font(.caption)
                Text("올라가지 않는 것: 체크·건너뛰기 기록, 식사, 휴가, 통계, 사진과 대시보드 배경, 기기·iCloud 정보.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 6. 확인

    private func confirmSection(_ draft: TemplateDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("공개 범위", selection: $isPublic) {
                Text("모두에게 공개").tag(true)
                Text("비공개로 저장").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("공개 범위")
            if isPublic {
                Toggle("위 내용이 모두에게 공개되는 것을 확인했어요", isOn: $confirmed)
            } else {
                Text("나만 볼 수 있어요. 내 템플릿에서 언제든 공개로 바꿀 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let message = error ?? (community.isSignedIn ? draft.validationError : nil), !(title.isEmpty && error == nil) {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isWorking { ProgressView().controlSize(.small) }
        }
    }

    // MARK: - 동작

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        sources = TemplatePublishing.sources(groups: store.groups, routines: store.routines)
        if let editing {
            title = editing.title
            summary = editing.summary
            authorName = editing.authorName
            category = editing.category
            tagsText = editing.tags.joined(separator: ", ")
            symbol = editing.thumbnail.symbol
            colorKey = editing.thumbnail.colorKey
            isPublic = editing.visibility == .public
        } else if let first = sources.first {
            // 처음에는 첫 그룹 하나만 골라 둔다(전부 올리는 것이 기본이 되지 않게).
            selected = [first.id]
            colorKey = GroupColor(rawValue: first.colorKey)?.rawValue ?? colorKey
        }
    }

    private func save() {
        isWorking = true
        error = nil
        let draft = draft
        Task {
            do {
                try await community.publish(draft, replacing: editing?.id)
                dismiss()
            } catch {
                self.error = CommunityStore.message(error)
            }
            isWorking = false
        }
    }
}

/// 그룹 하나와 그 루틴들: 이름, 요일, 시각, (있으면) 설명. 게시 전 확인과 내 템플릿 화면이 같이 쓴다.
struct TemplateGroupPreview: View {
    let group: RoutineTemplate.Group

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                if let key = group.colorKey {
                    Circle().fill(GroupColor(key: key).color).frame(width: 8, height: 8).accessibilityHidden(true)
                }
                Text(group.title).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            ForEach(Array(group.routines.enumerated()), id: \.offset) { _, routine in
                Divider().padding(.leading, 10)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(routine.title).font(.caption)
                        if !routine.note.isEmpty {
                            Text(routine.note).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Weekdays.summary(routine.weekdays) + (routine.time.isEmpty ? "" : " · \(routine.time)"))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
        }
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
