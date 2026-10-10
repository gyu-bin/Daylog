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
struct RoutineManagementView: View {
    @Environment(AppStore.self) private var store
    @State private var editor = RoutineEditorState()
    @State private var groupDraft = ""
    @State private var isAddingGroup = false
    @State private var showsArchivedGroups = false
    @FocusState private var newGroupFocused: Bool

    var body: some View {
        let active = store.activeGroups
        let archived = store.archivedGroups

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PageTitle(title: "루틴 관리", subtitle: "변경한 내용은 오늘부터 적용되고, 지난 기록은 바뀌지 않아요.")

                if active.isEmpty {
                    Card(fillsHeight: false) {
                        EmptyHint(
                            symbol: "square.stack.3d.up",
                            message: archived.isEmpty
                                ? "아직 그룹이 없어요.\n아래에 그룹 이름을 적고 Enter를 눌러 보세요."
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

                newGroupRow(alwaysOpen: active.isEmpty)

                if !archived.isEmpty {
                    ArchivedGroupsCard(groups: archived, isExpanded: $showsArchivedGroups)
                }

                Card(fillsHeight: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        CardHeader(symbol: "target", title: "달성한 날 기준값")
                        ThresholdControl()
                        Text("바꾸면 연속 달성일, 최장 연속 달성일, 달성 표시가 바로 다시 계산돼요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding(Theme.pagePadding)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .environment(editor)
        .routineEditorDialogs(editor)
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

    /// 항목 추가(그룹 안)와 헷갈리지 않게 그룹 목록 아래에 따로 둔다.
    @ViewBuilder
    private func newGroupRow(alwaysOpen: Bool) -> some View {
        if alwaysOpen || isAddingGroup {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                TextField("새 그룹", text: $groupDraft, prompt: Text("그룹 이름을 적고 Enter (예: 아침 루틴)"))
                    .textFieldStyle(.plain)
                    .focused($newGroupFocused)
                    .onSubmit(addGroup)
                    .onExitCommand {
                        groupDraft = ""
                        newGroupFocused = false
                        isAddingGroup = false
                    }
                    .accessibilityLabel("새 그룹 이름")
                Button("추가", action: addGroup)
                    .disabled(groupDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
        } else {
            Button(action: beginAddingGroup) {
                Label("새 그룹", systemImage: "plus")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("새 루틴 그룹을 만듭니다.")
        }
    }

    private func beginAddingGroup() {
        isAddingGroup = true
        newGroupFocused = true
    }

    /// 그룹을 만든 뒤에도 입력칸을 열어 두어 이어서 만들 수 있게 한다.
    private func addGroup() {
        if store.addGroup(title: groupDraft) != nil {
            groupDraft = ""
        }
        isAddingGroup = true
        newGroupFocused = true
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
