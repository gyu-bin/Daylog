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

    var body: some View {
        chrome
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

    // MARK: - 플랫폼별 틀

    #if os(macOS)
    private var chrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("루틴 편집")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(Self.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Theme.track, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")
                .help("저장하지 않고 닫기")
            }
            .padding(.bottom, 18)

            fields(daySize: 32)

            if let message = draft.validationMessage {
                validation(message).padding(.top, 14)
            }

            HStack(spacing: 8) {
                deleteButton
                Spacer()
                Button("취소", action: close)
                    .keyboardShortcut(.cancelAction)
                Button("저장", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.validationMessage != nil)
            }
            .padding(.top, 20)
        }
        .padding(22)
        .frame(width: 480)
    }
    #else
    private var chrome: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(Self.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    fields(daySize: 40)
                    if let message = draft.validationMessage {
                        validation(message)
                    }
                    Divider()
                    deleteButton
                }
                .padding(20)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.windowBackground)
            .navigationTitle("루틴 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: close)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(draft.validationMessage != nil)
                }
            }
        }
        // 아래로 쓸어 닫으면 취소와 같다(초안은 버려진다).
        .presentationDetents([.large])
    }
    #endif

    // MARK: - 입력 칸

    private func fields(daySize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
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
                WeekdaySelector(selection: $draft.weekdays, tint: tint, daySize: daySize)
            }

            field("예정 시간 (선택)") {
                timeRow
            }

            field("메모 (선택)") {
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
            Text("목록에 표시만 해요. 알림은 울리지 않아요.")
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

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            content()
        }
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
