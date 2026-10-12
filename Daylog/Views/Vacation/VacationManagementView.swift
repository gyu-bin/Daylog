import SwiftUI

struct VacationEditorTarget: Identifiable {
    let id = UUID()
    let day: Day
    var period: VacationPeriod?
}

private let vacationTint = GroupColor.blue.color

struct VacationSettingsSection: View {
    @Environment(AppStore.self) private var store
    @State private var showing = false

    var body: some View {
        Section {
            Button { showing = true } label: {
                LabeledContent("휴가 관리", value: store.vacationPeriods.isEmpty ? "없음" : "\(store.vacationPeriods.count)개 기간")
            }
        } header: {
            Text("휴가")
        } footer: {
            Text("휴가 날짜는 루틴 통계와 알림에서 제외돼요. 기존 체크와 식사 기록은 그대로 남습니다.")
        }
        .sheet(isPresented: $showing) { VacationManagementView() }
    }
}

/// 등록된 휴가 기간의 목록. 눌러서 고치거나 해제하고, 새 기간을 추가한다.
struct VacationManagementView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: VacationEditorTarget?

    var body: some View {
        SheetScaffold(
            title: "휴가 관리",
            subtitle: "휴가 날짜는 통계와 알림에서 제외되고, 연속 달성일은 휴가 전후로 이어져요.",
            width: 480, cancelTitle: "닫기", cancel: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    editing = VacationEditorTarget(day: store.today)
                } label: {
                    Label("휴가 추가", systemImage: "plus")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(vacationTint)

                if store.vacationPeriods.isEmpty {
                    EmptyHint(symbol: "sun.max", message: "등록된 휴가가 없어요.", tint: vacationTint)
                } else {
                    periodList
                }
            }
        }
        .sheet(item: $editing) { VacationEditorSheet(target: $0) }
    }

    /// 기간이 많으면 안에서 스크롤한다(시트가 화면 밖으로 자라지 않게).
    private var periodList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(store.vacationPeriods) { period in
                    Button {
                        editing = VacationEditorTarget(day: period.start, period: period)
                    } label: {
                        HStack(spacing: 10) {
                            VacationPeriodLabel(period: period)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("누르면 고치거나 해제합니다.")
                }
            }
        }
        .frame(maxHeight: 360)
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// 휴가 기간 한 줄: 해 아이콘, 날짜 범위와 날 수, 메모.
struct VacationPeriodLabel: View {
    let period: VacationPeriod

    static func rangeTitle(_ period: VacationPeriod) -> String {
        period.start == period.end
            ? period.start.longTitle
            : "\(period.start.shortTitle) (\(period.start.weekdaySymbol)) ~ \(period.end.shortTitle) (\(period.end.weekdaySymbol))"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(vacationTint)
                .frame(width: 26, height: 26)
                .background(vacationTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(Self.rangeTitle(period))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                    Text("\(period.start.days(until: period.end) + 1)일")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if !period.memo.isEmpty {
                    Text(period.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 보고 있는 날짜의 휴가 카드. 휴가가 아니면 추가 단추만, 휴가면 그 기간을 보여 준다.
struct VacationDayCard: View {
    @Environment(AppStore.self) private var store
    let day: Day
    @State private var editing: VacationEditorTarget?

    var body: some View {
        let periods = store.vacations(on: day)
        Card(fillsHeight: false, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: periods.isEmpty ? "sun.max" : "sun.max.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(vacationTint)
                        .frame(width: 24, height: 24)
                        .background(vacationTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .accessibilityHidden(true)
                    Text(periods.isEmpty ? "휴가 설정" : "휴가 · 통계 제외")
                        .font(.headline)
                    Spacer(minLength: 8)
                    HeaderLink(title: periods.isEmpty ? "기간 추가" : "추가") { editing = VacationEditorTarget(day: day) }
                }
                ForEach(periods) { period in
                    Button {
                        editing = VacationEditorTarget(day: day, period: period)
                    } label: {
                        HStack(spacing: 8) {
                            VacationPeriodLabel(period: period)
                            Spacer(minLength: 8)
                            Text("수정·해제")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("누르면 고치거나 해제합니다.")
                }
            }
        }
        .sheet(item: $editing) { VacationEditorSheet(target: $0) }
    }
}

/// 휴가 추가·수정. 달력에서 시작일과 종료일을 고르고, 메모를 적는다. 수정할 때는 해제도 할 수 있다.
struct VacationEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: VacationEditorTarget
    @State private var selection: DayRangeSelection
    @State private var memo: String
    @State private var error: String?
    @State private var confirmsRemoval = false

    init(target: VacationEditorTarget) {
        self.target = target
        _selection = State(initialValue: DayRangeSelection(
            start: target.period?.start ?? target.day, end: target.period?.end ?? target.day
        ))
        _memo = State(initialValue: target.period?.memo ?? "")
    }

    private var isEditing: Bool { target.period != nil }

    var body: some View {
        SheetScaffold(
            title: isEditing ? "휴가 수정" : "휴가 추가",
            subtitle: "휴가 날짜는 루틴 통계와 알림에서 빠져요. 체크와 식사 기록은 그대로 남아요.",
            width: 440, cancel: { dismiss() },
            primary: SheetAction(title: "저장", action: save)
        ) {
            if isEditing {
                Button("휴가 해제", role: .destructive) { confirmsRemoval = true }
                    .accessibilityLabel("이 휴가 기간 해제")
            }
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                rangeSummary
                DayRangeCalendar(selection: $selection, today: store.today, tint: vacationTint)
                SheetField(label: "메모 (선택)") {
                    TextField("메모", text: $memo, prompt: Text("예: 제주 여행"), axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("메모, 선택 사항")
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .alert("이 휴가 기간을 해제할까요?", isPresented: $confirmsRemoval) {
            Button("해제", role: .destructive, action: remove)
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 기간의 체크가 다시 통계에 반영돼요. 겹치는 다른 휴가 기간이 있으면 그 날짜는 휴가로 남아요.")
        }
    }

    /// 시작일·종료일 칩과 날 수. 칩을 누르면 그 날짜를 고치는 차례가 된다.
    private var rangeSummary: some View {
        HStack(spacing: 8) {
            edgeChip(.start, label: "시작일", day: selection.start)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            edgeChip(.end, label: "종료일", day: selection.end)
            Spacer(minLength: 4)
            Text(selection.dayCount == 1 ? "하루" : "\(selection.dayCount)일")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(vacationTint)
                .accessibilityLabel("총 \(selection.dayCount)일")
        }
    }

    private func edgeChip(_ edge: DayRangeSelection.Edge, label: String, day: Day) -> some View {
        let isActive = selection.editing == edge
        return Button {
            selection.editing = edge
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isActive ? vacationTint : .secondary)
                Text("\(day.shortTitle) (\(day.weekdaySymbol))")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? vacationTint.opacity(0.14) : Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .strokeBorder(isActive ? vacationTint : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(day.longTitle)")
        .accessibilityHint("누르면 달력에서 \(label)을 고릅니다.")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private func save() {
        if store.saveVacation(id: target.period?.id, start: selection.start, end: selection.end, memo: memo) {
            dismiss()
        } else {
            error = store.errorMessage ?? "저장하지 못했어요."
        }
    }

    private func remove() {
        guard let period = target.period else { return }
        if store.removeVacation(period) { dismiss() } else { error = store.errorMessage ?? "해제하지 못했어요." }
    }
}
