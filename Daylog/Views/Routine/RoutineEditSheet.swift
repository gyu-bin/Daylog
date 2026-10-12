import SwiftUI

/// 루틴 편집 화면. 초안만 고치다가 [저장]에서 한 번에 반영하고, [취소]하면 아무것도 바뀌지 않는다.
/// macOS에서는 가운데 뜨는 시트, iPhone·iPad에서는 제목 줄이 있는 시트로 보인다.
struct RoutineEditSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let routine: RoutineItem

    @State private var draft: RoutineDraft
    /// 시간을 껐다 켰을 때 되돌려 줄 값.
    @State private var rememberedTime: String
    @State private var confirmsDelete = false
    @State private var isClosed = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case title, note
    }

    private static let subtitle = "변경한 내용은 오늘부터 적용돼요. 지난 기록은 바뀌지 않아요."

    init(routine: RoutineItem) {
        self.routine = routine
        _draft = State(initialValue: RoutineDraft(routine))
        _rememberedTime = State(initialValue: TimeLabel.minutes(routine.timeLabel) == nil ? "07:00" : routine.timeLabel)
    }

    /// 고를 수 있는 그룹: 사용 중인 그룹과, 지금 속한 그룹(보관된 그룹일 수 있다).
    private var groupChoices: [RoutineGroup] {
        store.groups.filter { !$0.isArchived || $0.id == routine.effectiveGroupID }
    }

    private var tint: Color {
        GroupColor(key: store.groups.first { $0.id == draft.groupID }?.colorKey ?? "").color
    }

    #if os(macOS)
    private static let daySize: CGFloat = 32
    #else
    private static let daySize: CGFloat = 40
    #endif

    var body: some View {
        SheetScaffold(
            title: "루틴 편집", subtitle: Self.subtitle, width: 480, cancel: close,
            primary: SheetAction(title: "저장", isDisabled: draft.validationMessage != nil, action: save)
        ) {
            deleteButton
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                fields(daySize: Self.daySize)
                if let message = draft.validationMessage {
                    validation(message)
                }
            }
        }
            #if os(iOS)
            // 아래로 쓸어 닫으면 취소와 같다(초안은 버려진다).
            .presentationDetents([.large])
            #endif
            .onAppear {
                store.setEditing(true, source: "routine-sheet")
                #if os(macOS)
                focus = .title
                #endif
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

    // MARK: - 입력 칸

    private func fields(daySize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetField(label: "이름") {
                TextField("이름", text: $draft.title, prompt: Text("예: 물 한 잔 마시기"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("이름")
                    .focused($focus, equals: .title)
                    .onSubmit(save)
            }

            SheetField(label: "그룹") {
                Picker("그룹", selection: $draft.groupID) {
                    ForEach(groupChoices) { group in
                        Text(group.isArchived ? "\(group.title) (보관됨)" : group.title).tag(group.id)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("그룹")
            }

            SheetField(label: "반복 요일") {
                WeekdaySelector(selection: $draft.weekdays, tint: tint, daySize: daySize)
            }

            SheetField(label: "예정 시간 (선택)") {
                timeRow
            }

            SheetField(label: "메모 (선택)") {
                TextField("메모", text: $draft.note, prompt: Text("기억해 둘 내용"), axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("메모, 선택 사항")
                    .focused($focus, equals: .note)
            }
        }
    }

    /// 시간은 목록에 보여 주기만 한다(알림을 예약하지 않는다). 끄면 시간 없는 루틴이 된다.
    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Toggle("시간 정하기", isOn: hasTime)
                    .toggleStyle(.switch)
                    .tint(tint)
                    .labelsHidden()
                    .accessibilityLabel("예정 시간 정하기")
                if TimeLabel.minutes(draft.timeLabel) != nil {
                    DatePicker("예정 시간", selection: timeSelection, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .fixedSize()
                        .accessibilityLabel("예정 시간")
                } else if draft.timeLabel.isEmpty {
                    Text("시간 없음")
                        .foregroundStyle(.secondary)
                } else {
                    // 예전에 글자로 적어 둔 시간. 그대로 두거나 시각으로 바꿀 수 있다.
                    Text(draft.timeLabel)
                        .lineLimit(1)
                    Button("시각으로 바꾸기") {
                        draft.timeLabel = rememberedTime
                    }
                    .controlSize(.small)
                }
                Spacer(minLength: 0)
            }
            Text("목록에 표시돼요. 설정에서 루틴 알림을 켜면 이 시간에 알려 줘요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hasTime: Binding<Bool> {
        Binding(
            get: { !draft.timeLabel.isEmpty },
            set: { isOn in
                if isOn {
                    draft.timeLabel = rememberedTime
                } else {
                    if TimeLabel.minutes(draft.timeLabel) != nil { rememberedTime = draft.timeLabel }
                    draft.timeLabel = ""
                }
            }
        )
    }

    private var timeSelection: Binding<Date> {
        Binding(
            get: { TimeLabel.date(draft.timeLabel) ?? .now },
            set: {
                draft.timeLabel = TimeLabel.label(from: $0)
                rememberedTime = draft.timeLabel
            }
        )
    }

    private func validation(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    /// 삭제는 저장·취소와 떨어뜨려 두고, 한 번 더 묻는다. 지난 기록은 남는다.
    private var deleteButton: some View {
        Button("삭제…", role: .destructive) {
            confirmsDelete = true
        }
        .accessibilityLabel("\(routine.title) 삭제")
    }

    // MARK: - 저장과 닫기

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
