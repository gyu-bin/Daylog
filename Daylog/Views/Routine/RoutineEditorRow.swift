import SwiftUI

/// 루틴 한 개의 편집 행: 이름·시간·요일·메모·순서·보관.
struct RoutineEditorRow: View {
    @Environment(AppStore.self) private var store
    let routine: RoutineItem
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onTitleSubmitted: () -> Void

    // 입력 중에는 초안만 바꾸고, Enter를 누르거나 포커스가 떠날 때 한 번에 반영한다.
    @State private var title = ""
    @State private var timeLabel = ""
    @State private var note = ""
    @State private var showsWeekdayWarning = false
    @State private var isDropTarget = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case title, time, note
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 손잡이만 끌 수 있게 해서 입력 칸의 클릭·선택을 방해하지 않는다.
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 20, height: 24)
                .contentShape(Rectangle())
                .draggable(routine.id.uuidString) {
                    Text(routine.title)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
                }
                .help("끌어서 순서 변경")
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("루틴 이름", text: $title)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .focused($focus, equals: .title)
                        .onSubmit {
                            commit()
                            onTitleSubmitted()
                        }
                        .accessibilityLabel("루틴 이름")

                    TextField("시간", text: $timeLabel, prompt: Text("시간"))
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                        .frame(width: 72)
                        .focused($focus, equals: .time)
                        .onSubmit(commit)
                        .accessibilityLabel("\(routine.title) 시간")
                        .help("예: 07:30 (선택)")
                }

                HStack(spacing: 10) {
                    WeekdayPicker(selection: routine.weekdays, routineTitle: routine.title, onToggle: toggleWeekday)
                    presetButtons
                    Spacer(minLength: 0)
                    Text(Weekdays.summary(routine.weekdays))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }

                if showsWeekdayWarning {
                    Label("요일은 하나 이상 선택해야 해요. 쉬고 싶다면 루틴을 보관하세요.", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                TextField("메모", text: $note, prompt: Text("메모 (선택)"))
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .focused($focus, equals: .note)
                    .onSubmit(commit)
                    .accessibilityLabel("\(routine.title) 메모")
            }

            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Button {
                        store.moveActiveRoutine(routine, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(!canMoveUp)
                    .accessibilityLabel("\(routine.title) 위로 이동")
                    .help("위로 이동")

                    Button {
                        store.moveActiveRoutine(routine, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(!canMoveDown)
                    .accessibilityLabel("\(routine.title) 아래로 이동")
                    .help("아래로 이동")
                }
                Button("보관") {
                    commit()
                    store.setArchived(routine, true)
                }
                .accessibilityLabel("\(routine.title) 보관")
                .help("오늘 완료하지 않았다면 오늘 목록에서도 빠져요. 지난 기록은 그대로 남아요.")
            }
            .controlSize(.small)
        }
        .padding(.vertical, 10)
        .background(isDropTarget ? Theme.accentWash : .clear)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            store.moveActiveRoutine(id: id, to: routine.id)
            return true
        } isTargeted: {
            isDropTarget = $0
        }
        .onAppear(perform: loadDrafts)
        .onChange(of: focus) { oldValue, newValue in
            if oldValue != nil, oldValue != newValue { commit() }
            store.setEditing(newValue != nil, source: "routine-editor-\(routine.id.uuidString)")
        }
        .onDisappear {
            store.setEditing(false, source: "routine-editor-\(routine.id.uuidString)")
        }
    }

    private var presetButtons: some View {
        HStack(spacing: 4) {
            Button("매일") { setWeekdays(Weekdays.all) }
            Button("평일") { setWeekdays(Weekdays.workdays) }
            Button("주말") { setWeekdays(Weekdays.weekend) }
        }
        .controlSize(.small)
    }

    private func loadDrafts() {
        title = routine.title
        timeLabel = routine.timeLabel
        note = routine.note
    }

    /// 바뀐 항목만 저장한다. 이름을 비우면 원래 이름으로 되돌린다.
    private func commit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle = trimmedTitle.isEmpty || trimmedTitle == routine.title ? nil : trimmedTitle
        let newTime = timeLabel.trimmingCharacters(in: .whitespacesAndNewlines) == routine.timeLabel ? nil : timeLabel
        let newNote = note.trimmingCharacters(in: .whitespacesAndNewlines) == routine.note ? nil : note
        if newTitle != nil || newTime != nil || newNote != nil {
            store.updateRoutine(routine, title: newTitle, note: newNote, timeLabel: newTime)
        }
        loadDrafts()
    }

    private func toggleWeekday(_ weekday: Int) {
        var days = Set(routine.weekdays)
        if days.contains(weekday) {
            days.remove(weekday)
        } else {
            days.insert(weekday)
        }
        guard !days.isEmpty else {
            showsWeekdayWarning = true
            return
        }
        setWeekdays(days.sorted())
    }

    private func setWeekdays(_ days: [Int]) {
        showsWeekdayWarning = false
        guard days != routine.weekdays else { return }
        store.updateRoutine(routine, weekdays: days)
    }
}

/// 월~일 토글. 선택 여부를 색과 굵기, 접근성 상태로 함께 전달한다.
private struct WeekdayPicker: View {
    let selection: [Int]
    let routineTitle: String
    let onToggle: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Weekdays.all, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                Button {
                    onToggle(weekday)
                } label: {
                    Text(Weekdays.symbol(weekday))
                        .font(.callout.weight(isOn ? .bold : .regular))
                        .foregroundStyle(isOn ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.secondary))
                        .frame(width: 26, height: 26)
                        .background(isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.track), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(routineTitle) \(Weekdays.symbol(weekday))요일")
                .accessibilityValue(isOn ? "선택됨" : "선택 안 됨")
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
