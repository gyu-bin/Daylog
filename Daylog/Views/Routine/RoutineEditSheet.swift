import SwiftUI

/// 항목 편집 시트. 초안만 고치다가 [저장]에서 한 번에 반영하고, [취소]하면 아무것도 바뀌지 않는다.
struct RoutineEditSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let routine: RoutineItem

    @State private var draft: RoutineDraft
    @State private var confirmsDelete = false
    @State private var isClosed = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case title, time, note
    }

    init(routine: RoutineItem) {
        self.routine = routine
        _draft = State(initialValue: RoutineDraft(routine))
    }

    /// 고를 수 있는 그룹: 사용 중인 그룹과, 지금 속한 그룹(보관된 그룹일 수 있다).
    private var groupChoices: [RoutineGroup] {
        store.groups.filter { !$0.isArchived || $0.id == routine.effectiveGroupID }
    }

    private var tint: Color {
        GroupColor(key: store.groups.first { $0.id == draft.groupID }?.colorKey ?? "").color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("항목 편집")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 16)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 14) {
                field("이름") {
                    TextField("이름", text: $draft.title, prompt: Text("예: 물 한 잔 마시기"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("이름")
                        .focused($focus, equals: .title)
                        .onSubmit(save)
                }

                field("그룹") {
                    Picker("그룹", selection: $draft.groupID) {
                        ForEach(groupChoices) { group in
                            Text(group.isArchived ? "\(group.title) (보관됨)" : group.title).tag(group.id)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel("그룹")
                }

                field("반복 요일") {
                    HStack(spacing: 10) {
                        WeekdayPicker(selection: $draft.weekdays, tint: tint)
                        Spacer(minLength: 0)
                        HStack(spacing: 4) {
                            Button("매일") { draft.weekdays = Set(Weekdays.all) }
                                .accessibilityLabel("매일로 설정")
                            Button("평일") { draft.weekdays = Set(Weekdays.workdays) }
                                .accessibilityLabel("평일로 설정")
                            Button("주말") { draft.weekdays = Set(Weekdays.weekend) }
                                .accessibilityLabel("주말로 설정")
                        }
                        .controlSize(.small)
                    }
                }

                field("시간 (선택)") {
                    TextField("시간", text: $draft.timeLabel, prompt: Text("예: 07:30"))
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                        .frame(width: 110)
                        .accessibilityLabel("시간, 선택 사항")
                        .focused($focus, equals: .time)
                        .onSubmit(save)
                }

                field("메모 (선택)") {
                    TextField("메모", text: $draft.note, prompt: Text("기억해 둘 내용"), axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("메모, 선택 사항")
                        .focused($focus, equals: .note)
                }
            }

            Text(draft.validationMessage ?? "변경한 내용은 오늘부터 적용돼요. 지난 기록은 바뀌지 않아요.")
                .font(.caption)
                .foregroundStyle(draft.validationMessage == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                .padding(.top, 14)

            HStack(spacing: 8) {
                Button("삭제…", role: .destructive) {
                    confirmsDelete = true
                }
                .accessibilityLabel("\(routine.title) 삭제")
                Spacer()
                Button("취소") { close() }
                    .keyboardShortcut(.cancelAction)
                Button("저장", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.validationMessage != nil)
            }
            .padding(.top, 18)
        }
        .padding(22)
        .frame(width: 460)
        .onAppear {
            store.setEditing(true, source: "routine-sheet")
            focus = .title
        }
        .onDisappear {
            store.setEditing(false, source: "routine-sheet")
        }
        .alert("'\(routine.title)' 항목을 삭제할까요?", isPresented: $confirmsDelete) {
            Button("삭제", role: .destructive) {
                store.deleteRoutine(routine)
                close()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text(RoutineDeletion.itemMessage)
        }
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            content()
        }
    }

    /// Enter와 [저장] 버튼이 같은 입력에 함께 반응해도 한 번만 저장한다.
    private func save() {
        guard !isClosed, draft.validationMessage == nil else { return }
        if draft != RoutineDraft(routine), !store.apply(draft, to: routine) { return }
        close()
    }

    private func close() {
        isClosed = true
        dismiss()
    }
}

/// 월~일 토글. 선택 여부를 색과 굵기, 접근성 상태로 함께 전달한다.
private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Weekdays.all, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                Button {
                    if isOn {
                        selection.remove(weekday)
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(Weekdays.symbol(weekday))
                        .font(.callout.weight(isOn ? .bold : .regular))
                        .foregroundStyle(isOn ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.secondary))
                        .frame(width: 28, height: 28)
                        .background(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(Theme.track), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Weekdays.symbol(weekday))요일")
                .accessibilityValue(isOn ? "선택됨" : "선택 안 됨")
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
