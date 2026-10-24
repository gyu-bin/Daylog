import SwiftUI

/// 루틴 관리 화면이 띄우는 시트와 확인창의 상태. 그룹 카드와 항목 행이 함께 쓴다.
@Observable
final class RoutineEditorState {
    var editing: RoutineItem?
    var deletingRoutine: RoutineItem?
    var deletingGroup: RoutineGroup?
    var renamingGroup: RoutineGroup?
    var renameText = ""
    var recoloringGroupID: UUID?
}

/// 루틴 그룹과 항목의 추가·수정·순서 변경·보관·삭제. 변경은 오늘과 미래에만 적용되고 과거 기록은 그대로다.
/// 목록에는 이름·요일·시간만 보이고, 자세한 설정은 항목을 눌러 여는 편집 화면에서 한다.
struct RoutineManagementView: View {
    @Environment(AppStore.self) private var store
    @State private var editor = RoutineEditorState()
    @State private var groupDraft = ""
    @State private var isAddingGroup = false
    @State private var showsArchivedGroups = false
    /// 좁은 화면(iPhone)에서 템플릿을 시트로 연다. 넓은 화면은 사이드바의 템플릿 메뉴로 간다.
    @State private var showsTemplates = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var newGroupFocused: Bool

    private var pageTitle: some View {
        PageTitle(title: "루틴 관리", subtitle: "변경한 내용은 오늘부터 적용되고, 지난 기록은 바뀌지 않아요.")
    }

    @ViewBuilder
    private var headerButtons: some View {
        Button(action: openTemplates) {
            Label("템플릿", systemImage: "rectangle.stack")
                .font(.callout.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .fixedSize()
        .accessibilityHint("공식 루틴 템플릿을 둘러보고 가져옵니다.")
        Button(action: beginAddingGroup) {
            Label("새 그룹", systemImage: "plus")
                .font(.callout.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(GroupColor.blue.color)
        .fixedSize()
        .accessibilityHint("새 루틴 그룹을 만듭니다.")
    }

    /// 아래 탭에는 템플릿 메뉴가 없어서 시트로 띄우고, 사이드바가 있는 화면에서는 그 메뉴로 옮긴다.
    private func openTemplates() {
        if horizontalSizeClass == .compact { showsTemplates = true } else { store.section = .templates }
    }

    var body: some View {
        let active = store.activeGroups
        let archived = store.archivedGroups

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 넓으면 제목과 단추를 한 줄에, 좁으면(iPhone) 설명이 여러 줄로 꺾이지 않게 단추를 아래 줄로 내린다.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        pageTitle
                        Spacer(minLength: 8)
                        headerButtons
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        pageTitle
                        // 아주 큰 글자에서는 단추 두 개가 한 줄을 넘어 화면 전체가 옆으로 밀렸다. 그때는 세로로 쌓는다.
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { headerButtons }
                            VStack(alignment: .leading, spacing: 8) { headerButtons }
                        }
                    }
                }

                if active.isEmpty || isAddingGroup {
                    newGroupField
                }

                if active.isEmpty {
                    Card(fillsHeight: false) {
                        EmptyHint(
                            symbol: "square.stack.3d.up",
                            message: archived.isEmpty
                                ? "아직 그룹이 없어요.\n위에 그룹 이름을 적고 추가해 보세요. (예: 아침 루틴)"
                                : "사용 중인 그룹이 없어요.\n새로 만들거나 보관된 그룹을 복원하세요.",
                            tint: Theme.accent
                        )
                    }
                }

                ForEach(active) { group in
                    RoutineGroupCard(
                        group: group,
                        canMoveUp: group.id != active.first?.id,
                        canMoveDown: group.id != active.last?.id
                    )
                }

                if !archived.isEmpty {
                    ArchivedGroupsCard(groups: archived, isExpanded: $showsArchivedGroups)
                }
            }
            .pagePadding()
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .environment(editor)
        .routineEditorDialogs(editor)
        .sheet(isPresented: $showsTemplates) {
            TemplateLibraryView(onClose: { showsTemplates = false })
        }
        .onChange(of: store.quickAddFocusToken) {
            // ⌘N: 그룹이 하나도 없을 때만 여기서 받는다. 그룹이 있으면 해당 그룹 카드가 받는다.
            if store.quickAddGroup == nil { beginAddingGroup() }
        }
        .onChange(of: newGroupFocused) { _, isFocused in
            store.setEditing(isFocused, source: "new-group")
            if !isFocused, groupDraft.isEmpty { isAddingGroup = false }
        }
        .onDisappear {
            store.setEditing(false, source: "new-group")
        }
    }

    // MARK: - 새 그룹

    private var newGroupField: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .foregroundStyle(GroupColor.blue.color)
                .accessibilityHidden(true)
            TextField("새 그룹", text: $groupDraft, prompt: Text("그룹 이름 (예: 아침 루틴)"))
                .textFieldStyle(.plain)
                .focused($newGroupFocused)
                .onSubmit(addGroup)
                #if os(macOS)
                .onExitCommand(perform: cancelAddingGroup)
                #endif
                .accessibilityLabel("새 그룹 이름")
            Button("추가", action: addGroup)
                .disabled(groupDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if !store.activeGroups.isEmpty {
                Button("취소", action: cancelAddingGroup)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(GroupColor.blue.color.opacity(0.5), lineWidth: 1)
        )
    }

    private func beginAddingGroup() {
        isAddingGroup = true
        newGroupFocused = true
    }

    private func cancelAddingGroup() {
        groupDraft = ""
        newGroupFocused = false
        isAddingGroup = false
    }

    /// 그룹을 만든 뒤에는 입력칸을 닫는다. 이어서 그 그룹의 "+ 항목 추가"로 항목을 넣으면 된다.
    private func addGroup() {
        guard store.addGroup(title: groupDraft) != nil else {
            newGroupFocused = true
            return
        }
        cancelAddingGroup()
    }
}

/// 보관된 그룹 목록. 복원하거나 삭제할 수 있다.
private struct ArchivedGroupsCard: View {
    @Environment(AppStore.self) private var store
    @Environment(RoutineEditorState.self) private var editor
    let groups: [RoutineGroup]
    @Binding var isExpanded: Bool

    var body: some View {
        Card(fillsHeight: false, padding: 14) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 0) {
                    ForEach(groups) { group in
                        HStack(spacing: 10) {
                            GroupBadge(title: group.title, color: GroupColor(key: group.colorKey))
                            Text(group.title).lineLimit(1)
                            Text("항목 \(store.routines.filter { $0.effectiveGroupID == group.id }.count)개")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("복원") {
                                store.setGroupArchived(group, false)
                            }
                            .controlSize(.small)
                            .accessibilityLabel("\(group.title) 그룹 복원")
                            Button("삭제…", role: .destructive) {
                                editor.deletingGroup = group
                            }
                            .controlSize(.small)
                            .accessibilityLabel("\(group.title) 그룹 삭제")
                        }
                        .padding(.vertical, 6)
                        .padding(.leading, 12)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("보관된 그룹 \(groups.count)개")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
