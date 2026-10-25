import SwiftUI

/// 내 루틴을 템플릿 파일로 만들어 공유한다.
/// 공유할 루틴 → 제목·설명 → 분류·태그 → 파일에 들어갈 내용 확인 → [파일로 공유] 순서다.
/// 서버를 거치지 않고, 만들어진 파일을 시스템 공유(AirDrop·메시지·메신저)나 파일 저장으로 건넨다.
/// 이 화면은 루틴을 읽기만 한다: 공유해도 내 루틴·기록은 바뀌지 않는다.
struct TemplateShareSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var sources: [TemplatePublishing.GroupSource] = []
    /// 고른 루틴.
    @State private var selected: Set<UUID> = []
    @State private var includesNotes = false
    @State private var title = ""
    @State private var summary = ""
    @State private var category = TemplateCategory.lifestyle
    @State private var tagsText = ""
    @State private var showsRaw = false
    @State private var exports = false
    @State private var message: String?
    @State private var isLoaded = false
    /// 이 공유에 붙이는 임의의 ID. 화면을 여는 동안은 같은 값을 쓴다.
    @State private var fileID = UUID()

    private var groups: [RoutineTemplate.Group] {
        TemplatePublishing.groups(from: TemplatePublishing.selected(sources, routineIDs: selected), includesNotes: includesNotes)
    }

    private var template: RoutineTemplate {
        TemplateFile.make(
            id: fileID, title: title, summary: summary, category: category,
            tags: tagsText.split(whereSeparator: { $0 == "," || $0 == "#" || $0.isNewline }).map(String.init), groups: groups
        )
    }

    /// 고른 루틴 가운데 메모가 있는 것. 메모를 포함할지 정하기 전에 무엇이 실리는지 보여 준다.
    private var notedRoutines: [TemplatePublishing.GroupSource.RoutineSource] {
        sources.flatMap(\.routines).filter { selected.contains($0.id) && !$0.note.isEmpty }
    }

    var body: some View {
        let template = template
        let problem = groups.isEmpty ? "공유할 루틴을 하나 이상 골라 주세요." : template.validationError
        SheetScaffold(
            title: "내 루틴 공유하기", subtitle: "고른 루틴의 구성만 파일에 담아요. 체크·식사·휴가 같은 기록은 들어가지 않아요.",
            width: 560, cancelTitle: "닫기", cancel: { dismiss() }
        ) {
            EmptyView()
        } content: {
            SheetScrollArea(maxHeight: 540) {
                VStack(alignment: .leading, spacing: 18) {
                    selectionSection
                    textSection
                    categorySection
                    previewSection(template)
                    shareSection(template, problem: problem)
                }
            }
        }
        .onAppear(perform: load)
        .fileExporter(
            isPresented: $exports, document: TemplateFileDocument(data: (try? TemplateFile.encode(template)) ?? Data()),
            contentType: .daylogTemplate, defaultFilename: TemplateFile.fileName(for: template)
        ) { result in
            switch result {
            case .success: message = "파일을 저장했어요."
            case .failure(let error): message = error.localizedDescription
            }
        }
    }

    // MARK: - 1. 루틴 고르기

    private var selectionSection: some View {
        SheetField(label: "1. 공유할 그룹과 루틴") {
            if sources.isEmpty {
                Text("공유할 루틴이 없어요. 루틴 메뉴에서 그룹과 루틴을 먼저 만들어 주세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(sources) { source in
                VStack(alignment: .leading, spacing: 0) {
                    Toggle(isOn: groupBinding(source)) {
                        // 큰 글자 크기: 이름이 몇 글자로 잘리면 무엇을 고르는지 알 수 없다. 이름을 여러 줄로 쓰고 부가 정보는 아랫줄에 둔다.
                        let count = Text("\(source.routines.filter { selected.contains($0.id) }.count)/\(source.routines.count)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            GroupBadge(title: source.title, color: GroupColor(key: source.colorKey), size: 20)
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(source.title).font(.callout.weight(.semibold)).lineLimit(3)
                                    count
                                }
                            } else {
                                Text(source.title).font(.callout.weight(.semibold)).lineLimit(1)
                                count
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .accessibilityLabel("\(source.title) 그룹 전체")
                    ForEach(source.routines) { routine in
                        Divider().padding(.leading, 12)
                        Toggle(isOn: Binding(
                            get: { selected.contains(routine.id) },
                            set: { if $0 { selected.insert(routine.id) } else { selected.remove(routine.id) } }
                        )) {
                            let schedule = Text(Weekdays.summary(routine.weekdays) + (routine.timeLabel.isEmpty ? "" : " · \(routine.timeLabel)"))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(routine.title).font(.callout).lineLimit(3)
                                    schedule
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Text(routine.title).font(.callout).lineLimit(1)
                                    Spacer(minLength: 6)
                                    schedule
                                }
                            }
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 12)
                        .padding(.vertical, 6)
                        .accessibilityLabel(routine.title)
                    }
                }
                .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            }
        }
    }

    /// 그룹 머리의 스위치: 그 그룹의 루틴을 모두 고르거나 모두 뺀다.
    private func groupBinding(_ source: TemplatePublishing.GroupSource) -> Binding<Bool> {
        let ids = Set(source.routines.map(\.id))
        return Binding(
            get: { !ids.isDisjoint(with: selected) },
            set: { if $0 { selected.formUnion(ids) } else { selected.subtract(ids) } }
        )
    }

    // MARK: - 2~3. 제목, 설명, 분류, 태그

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetField(label: "2. 제목") {
                TextField("제목", text: $title, prompt: Text("예: 가볍게 시작하는 아침"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("템플릿 제목")
            }
            SheetField(label: "설명 (선택)") {
                TextField("설명", text: $summary, prompt: Text("어떤 루틴인지 한두 문장으로"), axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("템플릿 설명, 선택 사항")
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetField(label: "3. 분류") {
                FlowLayout(spacing: 6) {
                    ForEach(TemplateCategory.allCases) { item in
                        Button {
                            category = item
                        } label: {
                            Text(item.title)
                                .font(.callout.weight(category == item ? .semibold : .regular))
                                .foregroundStyle(category == item ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.primary))
                                .padding(.horizontal, 11)
                                .frame(minHeight: 30)
                                .background(category == item ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.inset), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title) 분류")
                        .accessibilityAddTraits(category == item ? [.isButton, .isSelected] : .isButton)
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

    // MARK: - 4. 파일에 들어갈 내용

    private func previewSection(_ template: RoutineTemplate) -> some View {
        SheetField(label: "4. 파일에 들어갈 내용") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    TemplateThumbnailView(thumbnail: template.thumbnail, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(template.title.isEmpty ? "제목 없음" : template.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(template.title.isEmpty ? .secondary : .primary)
                        if !template.summary.isEmpty {
                            Text(template.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(template.category.title + (template.tags.isEmpty ? "" : " · " + template.tags.map { "#\($0)" }.joined(separator: " "))
                            + " · 루틴 \(template.routineCount)개")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(Array(template.groups.enumerated()), id: \.offset) { _, group in
                    TemplateGroupPreview(group: group)
                }

                Toggle("루틴 메모도 파일에 포함", isOn: $includesNotes)
                    .disabled(notedRoutines.isEmpty)
                Text(notedRoutines.isEmpty
                    ? "고른 루틴에 적어 둔 메모가 없어요."
                    : includesNotes
                    ? "메모 \(notedRoutines.count)개가 위 목록처럼 그대로 들어가요. 개인적인 내용이 있으면 꺼 주세요."
                    : "메모가 있는 루틴 \(notedRoutines.count)개: " + notedRoutines.map(\.title).joined(separator: ", ") + ". 지금은 메모가 들어가지 않아요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                DisclosureGroup("파일 내용 그대로 보기", isExpanded: $showsRaw) {
                    Text(String(decoding: (try? TemplateFile.encode(template)) ?? Data("{}".utf8), as: UTF8.self))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .font(.caption)
                Text("들어가지 않는 것: 체크·건너뛰기 기록, 식사, 휴가, 통계, 사진과 대시보드 배경, 기기·iCloud 정보.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 5. 공유

    private func shareSection(_ template: RoutineTemplate, problem: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                ShareLink(
                    item: TemplateShareFile(template: template),
                    preview: SharePreview(TemplateFile.fileName(for: template), image: Image(systemName: "rectangle.stack"))
                ) {
                    Label("파일로 공유", systemImage: "square.and.arrow.up")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                Button {
                    exports = true
                } label: {
                    Label("파일로 저장", systemImage: "folder")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            .disabled(problem != nil)
            if let problem, !(title.isEmpty && !groups.isEmpty) {
                Label(problem, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if problem != nil {
                Text("제목을 적으면 공유할 수 있어요.").font(.caption).foregroundStyle(.secondary)
            }
            if let message {
                Label(message, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
            Text("받는 사람은 RoutiMori의 템플릿 화면에서 [파일에서 가져오기]로 열거나, 파일을 눌러 RoutiMori로 열 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        sources = TemplatePublishing.sources(groups: store.groups, routines: store.routines)
        // 처음에는 첫 그룹만 골라 둔다(전부 공유하는 것이 기본이 되지 않게).
        if let first = sources.first { selected = Set(first.routines.map(\.id)) }
    }
}
