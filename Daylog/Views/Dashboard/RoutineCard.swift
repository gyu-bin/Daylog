import SwiftUI

/// 보고 있는 날짜의 루틴 체크(그룹별), 빠른 추가, 내일 오전 할 일.
struct RoutineCard: View {
    @Environment(AppStore.self) var store
    /// 접어 둔 그룹의 ID(쉼표로 이어 붙인 문자열). 이 Mac에만 저장된다.
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage("collapsedGroupIDs") var collapsedGroupIDs = ""
    @State var itemDrafts: [UUID: String] = [:]
    @State private var groupDraft = ""
    @State private var isAddingGroup = false
    @State private var lastSuggestionAt = Date.distantPast
    @FocusState var focus: Field?

    enum Field: Hashable {
        case item(UUID)
        case newGroup
        case tomorrowTask
    }

    /// 화면에 그릴 그룹 한 칸. 체크가 있는 그룹은 그날의 스냅샷, 항목이 아직 없는 새 그룹은 현재 모습.
    struct Section: Identifiable {
        let group: GroupSnapshot
        let checks: [CheckValue]
        /// 오늘 항목을 추가할 수 있는 현재 그룹. 과거 날짜이거나 보관된 그룹이면 nil.
        let target: RoutineGroup?

        var id: UUID { group.id }
        var done: Int { checks.filter(\.isDone).count }
    }

    private var sections: [Section] {
        let active = store.activeGroups
        var result = store.checkSections.map { section in
            Section(
                group: section.group,
                checks: section.checks,
                target: store.isViewingToday ? active.first { $0.id == section.group.id } : nil
            )
        }
        guard store.isViewingToday else { return result }
        // 항목이 하나도 없는 그룹은 첫 항목을 넣을 수 있게 보여 준다.
        // 항목은 있는데 오늘 해당하는 것이 없는 그룹은 보여 주지 않는다.
        for group in active where !result.contains(where: { $0.id == group.id })
            && store.activeRoutines(inGroup: group.id).isEmpty {
            result.append(Section(group: GroupSnapshot(group), checks: [], target: group))
        }
        return result.sorted { ($0.group.order, $0.group.title) < ($1.group.order, $1.group.title) }
    }

    var body: some View {
        let sections = sections
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(symbol: "checklist", title: store.isViewingToday ? "오늘의 루틴" : "\(store.selectedDay.shortTitle)의 루틴") {
                    // 여기서는 기록만 한다. 이름·요일·순서 같은 편집은 루틴 관리 화면에서 한다.
                    HeaderLink(title: "루틴 관리") {
                        store.section = .routines
                    }
                }

                if sections.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                }

                if store.isViewingToday {
                    if store.activeGroups.isEmpty || isAddingGroup {
                        newGroupField
                    } else {
                        addGroupButton
                    }
                    if !store.suggestions.isEmpty, let group = store.quickAddGroup {
                        suggestionChips(into: group)
                    }
                } else {
                    pastDayNotice
                }

                if store.selectedOutcome.total > 0 {
                    progress
                }
                tomorrowTask
            }
        }
        .onChange(of: store.quickAddFocusToken) {
            focusQuickAdd()
        }
        .onChange(of: focus) { _, newValue in
            store.setEditing(newValue != nil, source: "routine")
            if newValue != .newGroup, groupDraft.isEmpty { isAddingGroup = false }
        }
    }

    // MARK: - 그룹 추가와 빈 상태

    @ViewBuilder
    private var emptyState: some View {
        if store.isViewingToday, store.activeGroups.isEmpty {
            EmptyHint(symbol: "sparkles", message: "첫 루틴을 만들어보세요.\n그룹 이름을 정하면 바로 항목을 적을 수 있어요.")
        } else if store.isViewingToday {
            EmptyHint(symbol: "cup.and.saucer", message: "오늘은 예정된 루틴이 없어요.")
        } else {
            EmptyHint(symbol: "calendar", message: "이 날짜에는 예정된 루틴이 없었어요.")
        }
    }

    /// 항목 추가(그룹 안의 "+ 항목 추가")와 헷갈리지 않게, 그룹 목록 아래에 따로 둔다.
    private var addGroupButton: some View {
        Button {
            isAddingGroup = true
            focus = .newGroup
        } label: {
            Label("새 그룹", systemImage: "folder.badge.plus")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("새 루틴 그룹을 만듭니다.")
    }

    private var newGroupField: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            TextField("새 그룹 이름", text: $groupDraft, prompt: Text("그룹 이름 (예: 아침 루틴)"))
                .textFieldStyle(.plain)
                .focused($focus, equals: .newGroup)
                .onSubmit(addGroup)
                .accessibilityLabel("새 그룹 이름")
                .accessibilityHint("Enter를 누르면 그룹이 만들어지고 바로 첫 항목을 적을 수 있습니다.")
            Button("추가", action: addGroup)
                .disabled(groupDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    /// 그룹을 만들면 곧바로 그 그룹의 항목 입력칸으로 넘어간다.
    private func addGroup() {
        guard let group = store.addGroup(title: groupDraft) else {
            focus = .newGroup
            return
        }
        groupDraft = ""
        isAddingGroup = false
        setCollapsed(group.id, false)
        DispatchQueue.main.async {
            focus = .item(group.id)
        }
    }

    /// ⌘N: 마지막으로 쓴 그룹(없으면 첫 그룹)의 항목 입력칸으로. 그룹이 없으면 그룹 이름 입력칸으로.
    private func focusQuickAdd() {
        if let group = store.quickAddGroup {
            setCollapsed(group.id, false)
            DispatchQueue.main.async {
                focus = .item(group.id)
            }
        } else {
            isAddingGroup = true
            focus = .newGroup
        }
    }

    /// 추천 항목. 어느 그룹에 들어가는지 글로 알려 주고, 누른 항목은 목록에서 바로 빠진다.
    private func suggestionChips(into group: RoutineGroup) -> some View {
        let color = GroupColor(key: group.colorKey)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text("추천 항목")
                    .font(.caption.weight(.semibold))
                Text("· 누르면")
                GroupBadge(title: group.title, color: color, size: 14)
                Text("\(group.title)에 매일 하는 항목으로 추가돼요.")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("추천 항목. 누르면 \(group.title) 그룹에 매일 하는 항목으로 추가됩니다.")

            FlowLayout(spacing: 6) {
                ForEach(store.suggestions, id: \.self) { suggestion in
                    Button {
                        addSuggestion(suggestion, to: group)
                    } label: {
                        Label(suggestion, systemImage: "plus")
                            .font(.callout)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(color.wash, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(group.title) 그룹에 \(suggestion) 추가")
                }
            }
        }
    }

    /// 칩을 누르면 그 칩이 사라지고 옆의 칩이 그 자리로 온다. 빠르게 두 번 누른 클릭이 옆 항목까지
    /// 추가하지 않도록, 방금 추가한 직후의 클릭은 받지 않는다.
    private func addSuggestion(_ title: String, to group: RoutineGroup) {
        let now = Date.now
        guard now.timeIntervalSince(lastSuggestionAt) > 0.6 else { return }
        if store.addSuggestion(title, in: group) {
            lastSuggestionAt = now
        }
    }

    private var pastDayNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text("그룹과 항목 추가는 오늘 날짜에서만 할 수 있어요.")
            Spacer(minLength: 0)
            Button("오늘로 이동") {
                store.goToToday()
            }
            .buttonStyle(.link)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: - 진행률과 내일 할 일

    private var progress: some View {
        let outcome = store.selectedOutcome
        return HStack(spacing: 12) {
            ProgressBar(ratio: outcome.ratio ?? 0, height: 10)
            Text("\(outcome.percentLabel) (\(outcome.done)/\(outcome.total))")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("전체 달성률 \(outcome.percentLabel), \(outcome.total)개 중 \(outcome.done)개 완료")
    }

    private var tomorrowTask: some View {
        let label = store.isViewingToday ? "내일 오전 할 일" : "다음 날 오전 할 일"
        return HStack(spacing: 10) {
            Label(label, systemImage: "lightbulb")
                .font(.callout.weight(.semibold))
                .fixedSize()
            TextField(
                label,
                text: Binding(
                    get: { store.text(\.tomorrowTask) },
                    set: { store.setText($0, at: \.tomorrowTask) }
                ),
                prompt: Text("한 줄로 적어 두세요")
            )
            .textFieldStyle(.roundedBorder)
            .focused($focus, equals: .tomorrowTask)
            .labelsHidden()
        }
        .id(store.selectedDay)
    }
}
