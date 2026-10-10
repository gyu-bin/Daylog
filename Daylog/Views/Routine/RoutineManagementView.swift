import SwiftUI

/// 루틴 그룹과 항목의 추가·수정·순서 변경·보관·복원. 변경은 오늘과 미래에만 적용되고 과거 기록은 그대로다.
struct RoutineManagementView: View {
    @Environment(AppStore.self) private var store
    @State private var groupDraft = ""
    @State private var showsArchivedGroups = false
    @FocusState private var newGroupFocused: Bool

    var body: some View {
        let active = store.activeGroups
        let archived = store.archivedGroups

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                VStack(alignment: .leading, spacing: 4) {
                    PageTitle(title: "루틴 관리")
                    Text("그룹을 만들고 그 안에 항목을 넣어 보세요. 변경한 내용은 오늘부터 적용되고, 지난 날짜의 기록은 바뀌지 않아요.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                newGroupCard

                if active.isEmpty {
                    Card {
                        EmptyHint(
                            symbol: "square.stack.3d.up",
                            message: archived.isEmpty
                                ? "아직 그룹이 없어요.\n위에 그룹 이름을 적고 Enter를 눌러 보세요."
                                : "사용 중인 그룹이 없어요.\n새로 만들거나 보관된 그룹을 복원하세요."
                        )
                    }
                }

                ForEach(active) { group in
                    GroupEditorCard(
                        group: group,
                        canMoveUp: group.id != active.first?.id,
                        canMoveDown: group.id != active.last?.id
                    )
                }

                if !archived.isEmpty {
                    archivedGroupsCard(archived)
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        CardHeader(symbol: "target", title: "달성한 날 기준값")
                        ThresholdControl()
                        Text("바꾸면 연속 달성일, 최장 연속 달성일, 달성 표시가 바로 다시 계산돼요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Theme.pagePadding)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var newGroupCard: some View {
        Card {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                TextField("새 그룹", text: $groupDraft, prompt: Text("새 그룹 이름을 적고 Enter (예: 아침 루틴)"))
                    .textFieldStyle(.plain)
                    .focused($newGroupFocused)
                    .onSubmit(addGroup)
                    .accessibilityLabel("새 그룹 이름")
                Button("그룹 추가", action: addGroup)
                    .disabled(groupDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addGroup() {
        if store.addGroup(title: groupDraft) != nil {
            groupDraft = ""
        }
        newGroupFocused = true
    }

    private func archivedGroupsCard(_ archived: [RoutineGroup]) -> some View {
        Card {
            DisclosureGroup(isExpanded: $showsArchivedGroups) {
                VStack(spacing: 0) {
                    ForEach(archived) { group in
                        Divider()
                        HStack(spacing: 10) {
                            GroupBadge(title: group.title, color: GroupColor(key: group.colorKey))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.title)
                                Text("항목 \(store.routines.filter { $0.effectiveGroupID == group.id }.count)개")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("복원") {
                                store.setGroupArchived(group, false)
                            }
                            .accessibilityLabel("\(group.title) 그룹 복원")
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("보관된 그룹 \(archived.count)개")
                    .font(.headline)
            }
        }
    }
}
