import SwiftUI

/// 보고 있는 날짜의 루틴 체크(그룹별)와 그룹 안의 항목 추가. 내일 오전 할 일은 `TomorrowTaskCard`에 있다.
/// 그룹을 만들고 지우고 설정하는 일은 루틴 관리 화면이 맡는다. 여기서는 오늘의 체크에 집중한다.
struct RoutineCard: View {
    @Environment(AppStore.self) var store
    @Environment(CloudSyncMonitor.self) private var sync
    @Environment(\.mobileUI) private var ui
    /// 접어 둔 그룹의 ID(쉼표로 이어 붙인 문자열). 이 Mac에만 저장된다.
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @AppStorage("collapsedGroupIDs") var collapsedGroupIDs = ""
    @State var itemDrafts: [UUID: String] = [:]
    /// 항목 입력칸을 펼쳐 둔 그룹. 평소에는 접어 두어 목록이 체크할 것만 보이게 한다.
    @State var addingGroupID: UUID?
    /// 휴가 안내에서 여는 휴가 수정 시트.
    @State private var editingVacation: VacationEditorTarget?
    @FocusState var focus: Field?

    enum Field: Hashable {
        case item(UUID)
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
        // 휴가인 날에는 보여 주기로 한 체크만 둔다. 새로 넣은 항목은 숨겨지므로 항목 추가도 열지 않는다.
        let canAdd = store.isViewingToday && !store.isVacation(on: store.selectedDay)
        var result = store.checkSections.map { section in
            Section(
                group: section.group,
                checks: section.checks,
                target: canAdd ? active.first { $0.id == section.group.id } : nil
            )
        }
        guard canAdd else { return result }
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
        let policy = store.routinePolicy(on: store.selectedDay)
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(symbol: "checklist", title: store.isViewingToday ? "오늘의 루틴" : "\(store.selectedDay.shortTitle)의 루틴") {
                    // 여기서는 기록만 한다. 이름·요일·순서 같은 편집은 루틴 관리 화면에서 한다.
                    HeaderLink(title: "루틴 관리") {
                        store.section = .routines
                    }
                }

                if policy == .fullRest {
                    // 전체 휴식: 체크리스트를 숨긴다. 기록은 그대로 있고, 휴가가 끝나거나 해제하면 다시 보인다.
                    vacationRest
                } else if policy.keepsRoutines {
                    vacationKeepNote(count: sections.reduce(0) { $0 + $1.checks.count })
                }

                if policy == .fullRest {
                    EmptyView()
                } else if sections.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                }

                if !store.isViewingToday, !policy.isVacation {
                    pastDayNotice
                }

                if store.selectedOutcome.ratio != nil {
                    progress
                }
            }
        }
        .sheet(item: $editingVacation) { VacationEditorSheet(target: $0) }
        .onChange(of: store.quickAddFocusToken) {
            focusQuickAdd()
        }
        .onChange(of: focus) { _, newValue in
            store.setEditing(newValue != nil, source: "routine")
            // 아무것도 적지 않고 입력칸을 떠나면 다시 접는다.
            if newValue == nil, let id = addingGroupID,
               (itemDrafts[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                addingGroupID = nil
            }
        }
    }

    // MARK: - 휴가

    /// 그날을 포함하는 휴가 기간 가운데 고칠 것(하나면 그것, 여럿이면 먼저 시작한 것).
    private var vacationToEdit: VacationPeriod? {
        store.vacations(on: store.selectedDay).min { ($0.start, $0.end) < ($1.start, $1.end) }
    }

    private var vacationRest: some View {
        EmptyHint(
            symbol: "beach.umbrella", message: "휴가 중이라 루틴은 쉬어요.\n기존 기록은 그대로 보관돼요.", tint: Theme.vacationTint,
            actionTitle: vacationToEdit == nil ? nil : "유지할 루틴 고르기"
        ) {
            if let period = vacationToEdit {
                editingVacation = VacationEditorTarget(day: period.start, period: period)
            }
        }
    }

    private func vacationKeepNote(count: Int) -> some View {
        Button {
            if let period = vacationToEdit {
                editingVacation = VacationEditorTarget(day: period.start, period: period)
            }
        } label: {
            Label(
                count == 0 ? "휴가 중 · 유지하는 루틴 가운데 이날 예정된 것이 없어요" : "휴가 중 · 고른 루틴 \(count)개만 보여요",
                systemImage: "beach.umbrella"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("누르면 유지할 루틴을 바꿉니다.")
    }

    // MARK: - 빈 상태와 빠른 추가

    @ViewBuilder
    private var emptyState: some View {
        if store.isViewingToday, !store.hasRoutines, sync.isWaitingForFirstImport {
            // iCloud를 쓰는데 아직 한 번도 가져오지 못했다. 다른 기기의 기록이 곧 내려올 수 있으니 "없다"고 단정하지 않는다.
            VStack(spacing: 10) {
                ProgressView()
                Text("iCloud에서 기록을 확인하는 중이에요.\n다른 기기에서 쓰던 기록이 있으면 잠시 뒤 나타나요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else if store.isViewingToday, !store.hasRoutines {
            // 그룹이나 루틴이 아직 없다. 만드는 곳(루틴 관리)으로 안내한다.
            EmptyHint(
                symbol: "checklist", message: ui.string(.emptyNoRoutinesYet), tint: Theme.accent,
                actionTitle: "루틴 관리에서 추가하기"
            ) {
                store.section = .routines
            }
        } else if store.isViewingToday {
            EmptyHint(symbol: "cup.and.saucer", message: ui.string(.emptyNoRoutinesToday))
        } else {
            EmptyHint(symbol: "calendar", message: "이 날짜에는 예정된 루틴이 없었어요.")
        }
    }

    /// ⌘N: 마지막으로 쓴 그룹(없으면 첫 그룹)의 항목 입력칸으로. 그룹이 없으면 그룹을 만드는 루틴 관리 화면으로.
    private func focusQuickAdd() {
        guard let group = store.quickAddGroup else {
            store.section = .routines
            return
        }
        setCollapsed(group.id, false)
        beginAdding(to: group.id)
    }

    private var pastDayNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text("항목 추가는 오늘 날짜에서만 할 수 있어요.")
            Spacer(minLength: 0)
            Button("오늘로 이동") {
                store.goToToday()
            }
            .buttonStyle(.borderless)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: - 진행률

    private var progress: some View {
        let outcome = store.selectedOutcome
        // 건너뛴 항목은 달성률에서 미완료와 같다. 몇 개를 쉬었는지만 옆에 적는다.
        let skipped = store.checkSections.reduce(0) { $0 + $1.skipped }
        // 큰 글자 크기에서는 숫자가 막대를 밀어내 점만 남는다. 막대를 윗줄에 따로 둔다.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            ProgressBar(ratio: outcome.ratio ?? 0, height: 10)
            HStack(spacing: 12) {
                Text("\(outcome.percentLabel) (\(outcome.done)/\(outcome.total))")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .fixedSize()
                if skipped > 0 {
                    Label("\(SkipStyle.label) \(skipped)", systemImage: SkipStyle.symbol)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(SkipStyle.ink)
                        .fixedSize()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "전체 달성률 \(outcome.percentLabel), \(outcome.total)개 중 \(outcome.done)개 완료"
                + (skipped > 0 ? ", \(skipped)개 건너뜀" : "")
        )
    }
}
