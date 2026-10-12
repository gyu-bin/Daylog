import SwiftUI

/// 휴가 중 루틴을 어떻게 할지: 모두 쉬거나, 고른 루틴만 이어 간다.
struct VacationRoutinePicker: View {
    @Environment(AppStore.self) private var store
    @Binding var keepsRoutines: Bool
    @Binding var kept: Set<UUID>

    var body: some View {
        SheetField(label: "휴가 중 루틴") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("휴가 중 루틴", selection: $keepsRoutines) {
                    Text("전체 휴식").tag(false)
                    Text("선택한 루틴만 유지").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if keepsRoutines {
                    routineList
                } else {
                    Text("휴가 동안 오늘 화면·위젯·메뉴 막대에서 루틴을 숨기고 알림도 쉬어요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// 그룹별로 묶은 지금의 루틴. 보관하거나 지운 루틴은 고를 수 없다.
    private var groups: [(group: RoutineGroup, routines: [RoutineItem])] {
        store.activeGroups.compactMap { group in
            let routines = store.activeRoutines(inGroup: group.id)
            return routines.isEmpty ? nil : (group, routines)
        }
    }

    @ViewBuilder
    private var routineList: some View {
        let groups = groups
        if groups.isEmpty {
            Text("고를 루틴이 없어요. 루틴을 먼저 만들어 주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                #if os(macOS)
                // macOS 시트는 내용만큼 자라므로 목록이 길면 안에서 스크롤한다.
                ScrollView {
                    rows(groups)
                }
                .frame(maxHeight: 190)
                .scrollBounceBehavior(.basedOnSize)
                #else
                rows(groups)
                #endif
                Text(Self.summary(selected: selectedCount))
                    .font(.caption)
                    .foregroundStyle(selectedCount == 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedCount: Int {
        kept.intersection(store.activeRoutines.map(\.id)).count
    }

    static func summary(selected: Int) -> String {
        selected == 0
            ? "유지할 루틴을 하나 이상 골라 주세요."
            : "고른 \(selected)개만 보이고 알림도 그 루틴만 와요. 달성률 통계는 휴가 동안 쉬어요."
    }

    private func rows(_ groups: [(group: RoutineGroup, routines: [RoutineItem])]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(groups, id: \.group.id) { entry in
                let color = GroupColor(key: entry.group.colorKey)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        GroupBadge(title: entry.group.title, color: color, size: 18)
                        Text(entry.group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.group.title) 그룹")
                    .accessibilityAddTraits(.isHeader)
                    ForEach(entry.routines, id: \.id) { routine in
                        row(routine, tint: color.color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ routine: RoutineItem, tint: Color) -> some View {
        let id = routine.id
        let isOn = kept.contains(id)
        return Button {
            if isOn { kept.remove(id) } else { kept.insert(id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
                    .accessibilityHidden(true)
                Text(routine.title)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !routine.timeLabel.isEmpty {
                    Text(routine.timeLabel)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, Self.rowPadding)
            .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(routine.title)
        .accessibilityValue(isOn ? "유지" : "휴식")
        .accessibilityHint("누르면 휴가 중에 이 루틴을 이어 갈지 바꿉니다.")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    #if os(macOS)
    private static let rowPadding: CGFloat = 6
    #else
    private static let rowPadding: CGFloat = 11
    #endif
}
