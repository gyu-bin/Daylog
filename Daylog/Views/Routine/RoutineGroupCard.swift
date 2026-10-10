import SwiftUI

/// 그룹 하나: 머리말(색·이름·항목 수·더 보기 메뉴)과 그 안의 항목 목록.
struct RoutineGroupCard: View {
    @Environment(AppStore.self) private var store
    @Environment(RoutineEditorState.self) private var editor
    let group: RoutineGroup
    let canMoveUp: Bool
    let canMoveDown: Bool

    @State private var itemDraft = ""
    @State private var showsArchivedItems = false
    @State private var isDropTarget = false
    @FocusState private var isAddFocused: Bool

    private var color: GroupColor { GroupColor(key: group.colorKey) }
    private var editingSource: String { "group-card-\(group.id.uuidString)" }

    var body: some View {
        let items = store.activeRoutines(inGroup: group.id)
        let archivedItems = store.archivedRoutines(inGroup: group.id)
        let otherGroups = store.activeGroups.filter { $0.id != group.id }
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)

        VStack(alignment: .leading, spacing: 0) {
            header(itemCount: items.count)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(items) { routine in
                    RoutineListRow(
                        routine: routine,
                        canMoveUp: routine.id != items.first?.id,
                        canMoveDown: routine.id != items.last?.id,
                        otherGroups: otherGroups,
                        tint: color.color
                    )
                }
                addItemRow
                if !archivedItems.isEmpty {
                    archivedItemsSection(archivedItems)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: shape)
        .overlay(shape.strokeBorder(isDropTarget ? color.color : Theme.cardBorder, lineWidth: isDropTarget ? 2 : 1))
        .clipShape(shape)
        // 그룹을 놓으면 순서 변경, 항목을 놓으면 이 그룹의 맨 뒤로 이동.
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first.flatMap(DragPayload.init(string:)) else { return false }
            switch payload {
            case .group(let id):
                store.moveGroup(id: id, to: group.id)
            case .item(let id):
                guard let routine = store.routines.first(where: { $0.id == id }) else { return false }
                store.moveRoutine(routine, to: group)
            }
            return true
        } isTargeted: {
            isDropTarget = $0
        }
        .onChange(of: store.quickAddFocusToken) {
            // ⌘N: 마지막으로 쓴 그룹(없으면 첫 그룹)의 입력칸으로 간다.
            if store.quickAddGroup?.id == group.id { isAddFocused = true }
        }
        .onChange(of: isAddFocused) { _, isFocused in
            store.setEditing(isFocused, source: editingSource)
        }
        .onDisappear {
            store.setEditing(false, source: editingSource)
        }
    }

    // MARK: - 머리말

    private func header(itemCount: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 18, height: 24)
                .contentShape(Rectangle())
                .draggable(DragPayload.group(group.id).string) {
                    Label(group.title, systemImage: "square.stack")
                        .padding(8)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
                }
                .help("끌어서 그룹 순서 변경")
                .accessibilityHidden(true)

            Button {
                editor.recoloringGroupID = group.id
            } label: {
                GroupBadge(title: group.title, color: color, size: 24)
            }
            .buttonStyle(.plain)
            .help("색상 변경")
            .accessibilityLabel("\(group.title) 그룹 색상 변경, 현재 \(color.label)")
            .popover(isPresented: recolorBinding, arrowEdge: .bottom) {
                ColorSwatches(selection: color, groupTitle: group.title) { picked in
                    store.updateGroup(group, colorKey: picked.rawValue)
                    editor.recoloringGroupID = nil
                }
                .padding(12)
            }

            Text(group.title)
                .font(.headline)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text("항목 \(itemCount)개")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer(minLength: 8)

            Menu {
                groupMenu
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 26, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("\(group.title) 그룹 더 보기")
            .help("이름·색상 변경, 이동, 보관, 삭제")
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(color.wash)
        .contextMenu { groupMenu }
    }

    private var recolorBinding: Binding<Bool> {
        Binding(
            get: { editor.recoloringGroupID == group.id },
            set: { if !$0, editor.recoloringGroupID == group.id { editor.recoloringGroupID = nil } }
        )
    }

    @ViewBuilder
    private var groupMenu: some View {
        Button("이름 변경…") {
            editor.renameText = group.title
            editor.renamingGroup = group
        }
        Button("색상 변경…") {
            editor.recoloringGroupID = group.id
        }
        Divider()
        Button("위로 이동") { store.moveGroup(group, by: -1) }
            .disabled(!canMoveUp)
        Button("아래로 이동") { store.moveGroup(group, by: 1) }
            .disabled(!canMoveDown)
        Divider()
        // 보관: 오늘부터 목록에서 빠지지만 복원할 수 있다. 삭제: 목록으로 되돌릴 수 없다.
        Button("보관") { store.setGroupArchived(group, true) }
        Button("삭제…", role: .destructive) { editor.deletingGroup = group }
    }

    // MARK: - 항목 추가와 보관된 항목

    private var addItemRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.color)
                .frame(width: 18)
                .accessibilityHidden(true)
            TextField("\(group.title)에 항목 추가", text: $itemDraft, prompt: Text("항목 추가"))
                .textFieldStyle(.plain)
                .focused($isAddFocused)
                .onSubmit(addItem)
                .accessibilityLabel("\(group.title) 그룹에 새 항목")
                .accessibilityHint("Enter를 누르면 매일 하는 항목으로 추가됩니다. 요일과 시간은 항목을 눌러 바꿉니다.")
            if !itemDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("추가", action: addItem)
                    .controlSize(.small)
                    .accessibilityLabel("\(group.title) 그룹에 항목 추가")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { isAddFocused = true }
    }

    /// Enter 후에도 포커스를 유지해 다음 항목을 이어서 입력할 수 있게 한다.
    private func addItem() {
        if store.addRoutine(title: itemDraft, in: group) {
            itemDraft = ""
        }
        isAddFocused = true
    }

    private func archivedItemsSection(_ archivedItems: [RoutineItem]) -> some View {
        DisclosureGroup(isExpanded: $showsArchivedItems) {
            ForEach(archivedItems) { routine in
                HStack(spacing: 8) {
                    Text(routine.title).lineLimit(1)
                    Text(Weekdays.summary(routine.weekdays))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("복원") {
                        store.setArchived(routine, false)
                    }
                    .controlSize(.small)
                    .accessibilityLabel("\(routine.title) 복원")
                    Button("삭제…", role: .destructive) {
                        editor.deletingRoutine = routine
                    }
                    .controlSize(.small)
                    .accessibilityLabel("\(routine.title) 삭제")
                }
                .padding(.vertical, 3)
                // 펼침 화살표 너비만큼 들여 써서 제목 글자와 줄을 맞춘다.
                .padding(.leading, 12)
            }
        } label: {
            Text("보관된 항목 \(archivedItems.count)개")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}
