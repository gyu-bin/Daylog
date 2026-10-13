import SwiftUI

/// 템플릿 미리보기와 가져오기. 무엇이 추가되고 무엇을 건너뛰는지 저장 전에 보여 주고, 저장한 뒤에는 결과를 알린다.
/// 저장은 파일 가져오기와 같은 서비스(`RoutineTransferService`)가 한다: 기존 루틴·기록은 고치지 않고, 오늘부터 적용된다.
struct TemplateDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(CommunityStore.self) private var community
    @Environment(\.dismiss) private var dismiss
    let template: RoutineTemplate
    @State private var reporting: CommunityTemplate?
    @State private var blocking: CommunityTemplate?
    /// 가져온 뒤 [루틴 보기]를 눌렀을 때.
    let showRoutines: () -> Void

    @State private var preview: RoutineImportPreview?
    @State private var error: String?
    @State private var result: TemplateImportResult?

    var body: some View {
        SheetScaffold(
            title: template.title,
            subtitle: "\(template.category.title) · 그룹 \(template.groups.count)개 · 루틴 \(template.routineCount)개",
            width: 520, cancelTitle: "닫기", cancel: { dismiss() },
            primary: result == nil
                ? SheetAction(title: "내 Daylog에 추가", isDisabled: !(preview?.canSave ?? false), action: save)
                : SheetAction(title: "루틴 보기", action: showRoutines)
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    TemplateThumbnailView(thumbnail: template.thumbnail, size: 56)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(template.summary)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        if !template.tags.isEmpty {
                            FlowLayout(spacing: 5) {
                                ForEach(template.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let shared = community.communityTemplate(for: template) { authorRow(shared) }
                if template.source == .file {
                    Label("받은 파일이에요. 아래 루틴을 확인한 뒤 추가하세요. 추가하기 전에는 아무것도 바뀌지 않아요.", systemImage: "doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let result {
                    resultBox(result)
                } else if let preview {
                    summaryBox(preview)
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SheetScrollArea(maxHeight: 320) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                            groupView(section)
                        }
                    }
                }
            }
        }
        .onAppear(perform: refresh)
        .sheet(item: $reporting) { TemplateReportSheet(template: $0) }
        .alert("이 게시자를 차단할까요?", isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } })) {
            Button("차단", role: .destructive) {
                guard let target = blocking else { return }
                Task {
                    do {
                        try await community.block(target.authorID)
                        dismiss()
                    } catch {
                        self.error = CommunityStore.message(error)
                    }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 게시자가 올린 템플릿이 목록에서 보이지 않아요. 내 템플릿 화면에서 해제할 수 있어요.")
        }
    }

    /// 다른 사람이 올린 템플릿: 게시자와 신고·차단. 내 것이면 안내만 보여 준다.
    private func authorRow(_ shared: CommunityTemplate) -> some View {
        HStack(spacing: 8) {
            Label("게시자 \(shared.displayAuthor)", systemImage: "person.crop.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if community.isMine(shared) {
                StatusBadge(text: "내가 올린 템플릿")
            } else {
                Button("신고") { reporting = shared }
                    .accessibilityLabel("이 템플릿 신고")
                Button("게시자 차단") {
                    if community.isSignedIn { blocking = shared } else { error = CommunityError.signInRequired.errorDescription }
                }
                .accessibilityLabel("이 게시자 차단")
            }
        }
        .controlSize(.small)
    }

    // MARK: - 그룹과 루틴

    private struct Section {
        let group: RoutineTemplate.Group
        /// 미리보기의 줄(템플릿의 루틴 순서와 같다). 미리보기를 만들지 못했으면 비어 있다.
        let rows: [RoutineImportPreview.Row?]
    }

    /// 미리보기의 줄은 템플릿의 그룹 → 루틴 순서 그대로라, 자리로 짝짓는다.
    private var sections: [Section] {
        var index = 0
        return template.groups.map { group in
            let rows = group.routines.map { _ -> RoutineImportPreview.Row? in
                defer { index += 1 }
                return preview.flatMap { $0.rows.indices.contains(index) ? $0.rows[index] : nil }
            }
            return Section(group: group, rows: rows)
        }
    }

    private func groupView(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(section.group.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let note = groupNote(section) {
                    StatusBadge(text: note)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .accessibilityAddTraits(.isHeader)

            ForEach(Array(section.group.routines.enumerated()), id: \.offset) { offset, routine in
                Divider().padding(.leading, 12)
                routineRow(routine, row: section.rows[offset])
            }
        }
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }

    /// 그 그룹이 새로 생기는지, 이미 있는 그룹에 들어가는지.
    private func groupNote(_ section: Section) -> String? {
        for case .create(let groupID)? in section.rows.map({ $0?.action }) {
            return groupID == nil ? "새 그룹" : "기존 그룹에 추가"
        }
        return nil
    }

    private func routineRow(_ routine: RoutineTemplate.Routine, row: RoutineImportPreview.Row?) -> some View {
        let state = RowState(row?.action, imported: result != nil)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: state.symbol)
                .font(.callout)
                .foregroundStyle(state.tint)
                .frame(width: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.title)
                    .font(.callout)
                    .foregroundStyle(state.isSkipped ? .secondary : .primary)
                    .lineLimit(2)
                if let note = state.note ?? (routine.note.isEmpty ? nil : routine.note) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(state.isError ? AnyShapeStyle(GroupColor.coral.ink) : AnyShapeStyle(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Weekdays.summary(routine.weekdays))
                    .font(.caption.weight(.medium))
                if !routine.time.isEmpty {
                    Text(routine.time)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityValue(state.accessibilityValue)
    }

    /// 루틴 한 줄의 상태 표시.
    private struct RowState {
        let symbol: String
        let tint: Color
        /// 건너뛰거나 오류인 까닭. 추가되는 줄은 nil(루틴의 메모를 보여 준다).
        let note: String?
        let isSkipped: Bool
        let isError: Bool
        let accessibilityValue: String

        init(_ action: RoutineImportPreview.Action?, imported: Bool) {
            switch action {
            case .create:
                (symbol, tint, note) = (imported ? "checkmark.circle.fill" : "plus.circle.fill", Theme.accent, nil)
                (isSkipped, isError, accessibilityValue) = (false, false, imported ? "추가됨" : "추가 예정")
            case .duplicate, .conflict:
                (symbol, tint, note) = ("equal.circle", .secondary, action?.label)
                (isSkipped, isError, accessibilityValue) = (true, false, "건너뜀")
            case .error(let message):
                (symbol, tint, note) = ("exclamationmark.circle.fill", GroupColor.coral.color, message)
                (isSkipped, isError, accessibilityValue) = (true, true, "오류")
            case nil:
                (symbol, tint, note) = ("circle", .secondary, nil)
                (isSkipped, isError, accessibilityValue) = (false, false, "")
            }
        }
    }

    // MARK: - 요약과 결과

    private func summaryBox(_ preview: RoutineImportPreview) -> some View {
        infoBox(
            symbol: preview.canSave ? "plus.circle.fill" : "equal.circle", tint: preview.canSave ? Theme.accent : .secondary,
            title: TemplateImportResult.previewTitle(preview),
            detail: preview.canSave
                ? "기존 루틴과 기록은 바뀌지 않아요. 새 루틴은 오늘부터 적용되고 지난 날짜에는 들어가지 않아요."
                : preview.errorCount > 0 ? "오류가 있는 줄 때문에 추가할 수 없어요." : "이 템플릿의 루틴이 이미 모두 있어요."
        )
    }

    private func resultBox(_ result: TemplateImportResult) -> some View {
        infoBox(
            symbol: "checkmark.circle.fill", tint: Theme.accent, title: result.title,
            detail: "오늘부터 루틴에 나와요. 지난 기록과 대시보드 배치는 그대로예요."
        )
    }

    private func infoBox(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 동작

    private func refresh() {
        do {
            preview = try store.previewTemplateImport(template)
        } catch {
            preview = nil
            self.error = error.localizedDescription
        }
    }

    private func save() {
        guard let confirmed = preview else { return }
        if store.confirmRoutineImport(confirmed) {
            error = nil
            result = TemplateImportResult(created: confirmed.createdCount, skipped: confirmed.duplicateCount, failed: confirmed.errorCount)
        } else {
            // 저장하지 못했다: 아무것도 추가되지 않았다. 지금 상태로 다시 미리 본다.
            error = store.errorMessage ?? "저장하지 못했어요. 다시 시도해 주세요."
            store.errorMessage = nil
            refresh()
        }
    }
}

/// 템플릿 가져오기의 결과 문구.
struct TemplateImportResult: Equatable {
    var created: Int
    var skipped: Int
    var failed: Int

    /// "루틴 3개를 추가했어요 · 1개는 이미 있어 건너뛰었어요".
    var title: String {
        var parts = ["루틴 \(created)개를 추가했어요"]
        if skipped > 0 { parts.append("\(skipped)개는 이미 있어 건너뛰었어요") }
        if failed > 0 { parts.append("오류 \(failed)개") }
        return parts.joined(separator: " · ")
    }

    /// 저장 전 요약: "추가 3개 · 건너뜀 1개".
    static func previewTitle(_ preview: RoutineImportPreview) -> String {
        var parts = ["추가 \(preview.createdCount)개"]
        if preview.duplicateCount > 0 { parts.append("건너뜀 \(preview.duplicateCount)개") }
        if preview.errorCount > 0 { parts.append("오류 \(preview.errorCount)개") }
        return parts.joined(separator: " · ")
    }
}
