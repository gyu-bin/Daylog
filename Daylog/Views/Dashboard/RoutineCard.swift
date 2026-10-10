import SwiftUI

/// 보고 있는 날짜의 루틴 체크, 빠른 추가, 내일 오전 할 일.
struct RoutineCard: View {
    @Environment(AppStore.self) private var store
    @State private var draft = ""
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case quickAdd, tomorrowTask
    }

    /// 뷰가 모델 객체를 붙잡지 않도록 행에는 값만 넘긴다(보관으로 체크가 삭제될 수 있다).
    private struct Row: Identifiable, Equatable {
        let id: UUID
        let title: String
        let timeLabel: String
        let note: String
        let isDone: Bool
    }

    private var rows: [Row] {
        store.checks.map {
            Row(id: $0.routineID, title: $0.title, timeLabel: $0.timeLabel, note: $0.note, isDone: $0.isDone)
        }
    }

    var body: some View {
        let rows = rows
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(symbol: "checklist", title: store.isViewingToday ? "오늘의 루틴" : "\(store.selectedDay.shortTitle)의 루틴") {
                    Button("루틴 편집") {
                        store.section = .routines
                    }
                }

                if rows.isEmpty {
                    emptyState
                } else {
                    checkList(rows)
                }

                if store.isViewingToday {
                    quickAdd
                    if !store.suggestions.isEmpty {
                        suggestionChips
                    }
                } else {
                    pastDayNotice
                }

                Spacer(minLength: 0)

                if !rows.isEmpty {
                    progress
                }
                tomorrowTask
            }
        }
        .onChange(of: store.quickAddFocusToken) {
            focus = .quickAdd
        }
        .onChange(of: focus) { _, newValue in
            store.setEditing(newValue != nil, source: "routine")
        }
    }

    // MARK: - 목록

    private func checkList(_ rows: [Row]) -> some View {
        let showsTime = rows.contains { !$0.timeLabel.isEmpty }
        let showsNote = rows.contains { !$0.note.isEmpty }
        return VStack(spacing: 0) {
            ForEach(rows) { row in
                Divider()
                Toggle(isOn: Binding(
                    get: { row.isDone },
                    set: { store.setDone(routineID: row.id, $0) }
                )) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if showsTime {
                            Text(row.timeLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 60, alignment: .leading)
                        }
                        if showsNote {
                            Text(row.note)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .toggleStyle(RoutineCheckStyle())
                .padding(.vertical, 7)
            }
            Divider()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasRoutines {
            EmptyHint(symbol: "leaf", message: "아직 루틴이 없어요.\n매일 하고 싶은 일을 하나 적어보세요.")
        } else if store.isViewingToday {
            EmptyHint(symbol: "cup.and.saucer", message: "오늘은 예정된 루틴이 없어요.")
        } else {
            EmptyHint(symbol: "calendar", message: "이 날짜에는 예정된 루틴이 없었어요.")
        }
    }

    // MARK: - 빠른 추가

    private var quickAdd: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            TextField(
                "새 루틴",
                text: $draft,
                prompt: Text(store.hasRoutines ? "루틴 추가 (Enter)" : "예: 아침 운동 30분")
            )
            .textFieldStyle(.plain)
            .focused($focus, equals: .quickAdd)
            .onSubmit(addRoutine)
            .accessibilityLabel("새 루틴 이름")
            .accessibilityHint("Enter를 누르면 매일 하는 루틴으로 추가됩니다.")

            if !store.hasRoutines || !draft.isEmpty {
                Button("추가", action: addRoutine)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(Theme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
        .help("새 루틴 (⌘N)")
    }

    private var suggestionChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(store.suggestions, id: \.self) { suggestion in
                Button {
                    store.addRoutine(title: suggestion)
                } label: {
                    Label(suggestion, systemImage: "plus")
                        .font(.callout)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accentWash, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(suggestion) 루틴 추가")
            }
        }
    }

    private var pastDayNotice: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text("루틴 추가는 오늘 날짜에서만 할 수 있어요.")
            Spacer(minLength: 0)
            Button("오늘로 이동") {
                store.goToToday()
            }
            .buttonStyle(.link)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private func addRoutine() {
        if store.addRoutine(title: draft) {
            draft = ""
        }
        focus = .quickAdd
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
        .accessibilityLabel("달성률 \(outcome.percentLabel), \(outcome.total)개 중 \(outcome.done)개 완료")
    }

    private var tomorrowTask: some View {
        let label = store.isViewingToday ? "내일 오전 할 일" : "다음 날 오전 할 일"
        return HStack(spacing: 10) {
            Label(label, systemImage: "doc.text")
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

/// 체크 표시와 이름 전체가 눌리는 체크박스. VoiceOver에는 표준 체크박스로 보인다.
struct RoutineCheckStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 19))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        configuration.isOn ? Theme.onAccent : Color.secondary,
                        configuration.isOn ? Theme.accent : Color.secondary
                    )
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
            .toggleStyle(.checkbox)
        }
    }
}
