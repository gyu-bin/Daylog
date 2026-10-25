import SwiftUI

/// 루틴 항목 한 줄: 이름, 요일 요약, 시간, 더 보기 메뉴. 누르면 편집 시트가 열린다.
struct RoutineListRow: View {
    @Environment(AppStore.self) private var store
    @Environment(RoutineEditorState.self) private var editor
    let routine: RoutineItem
    let canMoveUp: Bool
    let canMoveDown: Bool
    /// 이 항목을 옮길 수 있는 다른 그룹들.
    let otherGroups: [RoutineGroup]
    /// 속한 그룹의 색.
    let tint: Color

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isHovered = false
    @State private var isDropTarget = false

    var body: some View {
        HStack(spacing: 8) {
            // 손잡이만 끌 수 있게 해서 행 클릭(편집)을 방해하지 않는다.
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 18, height: 22)
                .contentShape(Rectangle())
                .draggable(DragPayload.item(routine.id).string) {
                    Text(routine.title)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
                }
                .help("끌어서 순서 변경")
                .accessibilityHidden(true)

            Button {
                editor.editing = routine
            } label: {
                Group {
                    if isStacked {
                        // 좁은 화면(iPhone)과 큰 글자 크기: 이름을 온전히 보여 주고, 요일과 시간은 아랫줄에 둔다.
                        VStack(alignment: .leading, spacing: 4) {
                            titles(lineLimit: dynamicTypeSize.isAccessibilitySize ? nil : 3)
                            // 큰 글자에서 요일 칩과 시간을 한 줄에 고정하면 시간이 "0…"으로 잘렸다. 들어가는 만큼씩 줄을 바꾼다.
                            FlowLayout(spacing: 8) {
                                weekdayChip
                                if !routine.timeLabel.isEmpty { timeLabel.fixedSize() }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(spacing: 10) {
                            titles(lineLimit: 1)
                            Spacer(minLength: 8)
                            // 요일 → 시간 순서로, 줄마다 같은 자리에 오도록 시간 칸의 너비를 고정한다.
                            weekdayChip
                            Group {
                                if routine.timeLabel.isEmpty { Color.clear } else { timeLabel }
                            }
                            .frame(width: 74, alignment: .leading)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityHint("누르면 편집합니다.")

            Menu {
                rowMenu
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .tint(.secondary)
            .fixedSize()
            .accessibilityLabel("\(routine.title) 더 보기")
            .help("편집, 이동, 보관, 삭제")
        }
        .padding(.leading, 2)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        .contextMenu { rowMenu }
        .dropDestination(for: String.self) { items, _ in
            // 항목만 받는다. 그룹을 놓은 경우는 바깥의 그룹 카드가 처리하도록 넘긴다.
            guard case .item(let id)? = items.first.flatMap(DragPayload.init(string:)) else { return false }
            store.moveActiveRoutine(id: id, to: routine.id)
            return true
        } isTargeted: {
            isDropTarget = $0
        }
    }

    /// 이름과 요일·시간을 두 줄로 쌓을지.
    private var isStacked: Bool {
        horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }

    private func titles(lineLimit: Int?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(routine.title)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
            if !routine.note.isEmpty {
                Text(routine.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
        }
    }

    private var weekdayChip: some View {
        Text(Weekdays.summary(routine.weekdays))
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.track, in: Capsule())
            .fixedSize()
    }

    private var timeLabel: some View {
        Label(routine.timeLabel, systemImage: "clock")
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var rowBackground: Color {
        if isDropTarget { return tint.opacity(0.2) }
        return isHovered ? Theme.inset : .clear
    }

    private var accessibilitySummary: String {
        var parts = [routine.title, Weekdays.summary(routine.weekdays)]
        if !routine.timeLabel.isEmpty { parts.append(routine.timeLabel) }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var rowMenu: some View {
        Button("편집…") { editor.editing = routine }
        if !otherGroups.isEmpty {
            Menu("다른 그룹으로 이동") {
                ForEach(otherGroups) { group in
                    Button(group.title) { store.moveRoutine(routine, to: group) }
                }
            }
        }
        Divider()
        Button("위로 이동") { store.moveActiveRoutine(routine, by: -1) }
            .disabled(!canMoveUp)
        Button("아래로 이동") { store.moveActiveRoutine(routine, by: 1) }
            .disabled(!canMoveDown)
        Divider()
        // 보관: 오늘 완료하지 않았다면 오늘 목록에서도 빠지고, 복원할 수 있다.
        Button("보관") { store.setArchived(routine, true) }
        Button("삭제…", role: .destructive) { editor.deletingRoutine = routine }
    }
}
