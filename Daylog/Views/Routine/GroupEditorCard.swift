import SwiftUI

/// 그룹 하나: 이름·색·순서·보관과 그 안의 항목들.
struct GroupEditorCard: View {
    @Environment(AppStore.self) private var store
    let group: RoutineGroup
    let canMoveUp: Bool
    let canMoveDown: Bool

    @State private var title = ""
    @State private var itemDraft = ""
    @State private var showsArchivedItems = false
    @State private var isDropTarget = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case title, newItem
    }

    private var color: GroupColor { GroupColor(key: group.colorKey) }

    var body: some View {
        let items = store.activeRoutines(inGroup: group.id)
        let archivedItems = store.archivedRoutines(inGroup: group.id)
        let otherGroups = store.activeGroups.filter { $0.id != group.id }

        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { routine in
                    RoutineEditorRow(
                        routine: routine,
                        canMoveUp: routine.id != items.first?.id,
                        canMoveDown: routine.id != items.last?.id,
                        otherGroups: otherGroups,
                        tint: color.color,
                        onTitleSubmitted: { focus = .newItem }
                    )
                    Divider()
                }
                addItemRow
                if !archivedItems.isEmpty {
                    Divider()
                    archivedItemsSection(archivedItems)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(isDropTarget ? color.color : Theme.separator, lineWidth: isDropTarget ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
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
        .onAppear { title = group.title }
        .onChange(of: group.title) { _, newValue in
            if focus != .title { title = newValue }
        }
        .onChange(of: focus) { oldValue, newValue in
            if oldValue == .title, newValue != .title { commitTitle() }
            store.setEditing(newValue != nil, source: "group-editor-\(group.id.uuidString)")
        }
        .onDisappear {
            store.setEditing(false, source: "group-editor-\(group.id.uuidString)")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 24)
                .contentShape(Rectangle())
                .draggable(DragPayload.group(group.id).string) {
                    Label(group.title, systemImage: "square.stack")
                        .padding(8)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
                }
                .help("끌어서 그룹 순서 변경")
                .accessibilityHidden(true)

            GroupBadge(title: group.title, color: color, size: 26)

            TextField("그룹 이름", text: $title)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .focused($focus, equals: .title)
                .onSubmit {
                    commitTitle()
                    focus = .newItem
                }
                .accessibilityLabel("그룹 이름")

            ColorSwatches(selection: color, groupTitle: group.title) { picked in
                store.updateGroup(group, colorKey: picked.rawValue)
            }

            HStack(spacing: 2) {
                Button {
                    store.moveGroup(group, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveUp)
                .accessibilityLabel("\(group.title) 그룹 위로 이동")
                .help("그룹을 위로")

                Button {
                    store.moveGroup(group, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDown)
                .accessibilityLabel("\(group.title) 그룹 아래로 이동")
                .help("그룹을 아래로")

                Button("보관") {
                    commitTitle()
                    store.setGroupArchived(group, true)
                }
                .accessibilityLabel("\(group.title) 그룹 보관")
                .help("그룹과 그 안의 항목이 오늘부터 목록에서 빠져요. 항목과 지난 기록은 그대로 남고, 복원하면 돌아와요.")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 10)
        .background(color.wash)
    }

    private var addItemRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(color.color)
                .accessibilityHidden(true)
            TextField("새 항목", text: $itemDraft, prompt: Text("항목 이름을 적고 Enter"))
                .textFieldStyle(.plain)
                .focused($focus, equals: .newItem)
                .onSubmit(addItem)
                .accessibilityLabel("\(group.title) 그룹에 새 항목")
            Button("추가", action: addItem)
                .disabled(itemDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.top, 12)
    }

    private func archivedItemsSection(_ archivedItems: [RoutineItem]) -> some View {
        DisclosureGroup(isExpanded: $showsArchivedItems) {
            ForEach(archivedItems) { routine in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.title)
                        Text(Weekdays.summary(routine.weekdays))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("복원") {
                        store.setArchived(routine, false)
                    }
                    .accessibilityLabel("\(routine.title) 복원")
                }
                .padding(.vertical, 4)
            }
        } label: {
            Text("보관된 항목 \(archivedItems.count)개")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
    }

    /// 이름을 비우면 원래 이름으로 되돌린다.
    private func commitTitle() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != group.title {
            store.updateGroup(group, title: trimmed)
        }
        title = group.title
    }

    /// Enter 후에도 포커스를 유지해 다음 항목을 이어서 입력할 수 있게 한다.
    private func addItem() {
        if store.addRoutine(title: itemDraft, in: group) {
            itemDraft = ""
        }
        focus = .newItem
    }
}
