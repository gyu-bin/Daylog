import SwiftUI

struct VacationEditorTarget: Identifiable {
    let id = UUID()
    let day: Day
    var period: VacationPeriod?
}

struct VacationSettingsSection: View {
    @Environment(AppStore.self) private var store
    @State private var showing = false

    var body: some View {
        Section {
            Button { showing = true } label: {
                LabeledContent("휴가 관리", value: "\(store.vacationPeriods.count)개 기간")
            }
        } header: {
            Text("휴가")
        } footer: {
            Text("휴가 날짜는 루틴 통계와 알림에서 제외돼요. 기존 체크와 식사 기록은 그대로 남습니다.")
        }
        .sheet(isPresented: $showing) { VacationManagementView() }
    }
}

struct VacationManagementView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: VacationEditorTarget?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("휴가 추가", systemImage: "plus") {
                        editing = VacationEditorTarget(day: store.today)
                    }
                } footer: {
                    Text("하루 또는 기간을 선택하세요. 겹친 기간은 한 번만 제외하며, 연속 달성일은 휴가 전후로 이어집니다.")
                }
                if store.vacationPeriods.isEmpty {
                    Text("등록된 휴가가 없어요.").foregroundStyle(.secondary)
                }
                ForEach(store.vacationPeriods) { period in
                    Button {
                        editing = VacationEditorTarget(day: period.start, period: period)
                    } label: {
                        VacationPeriodLabel(period: period)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("휴가 관리")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .sheet(item: $editing) { VacationEditorSheet(target: $0) }
        }
        #if os(macOS)
        .frame(width: 520, height: 500)
        #endif
    }
}

struct VacationPeriodLabel: View {
    let period: VacationPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(period.start == period.end ? period.start.longTitle : "\(period.start.key) ~ \(period.end.key)",
                  systemImage: "sun.max")
                .font(.callout.weight(.semibold))
            if !period.memo.isEmpty {
                Text(period.memo).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VacationDayCard: View {
    @Environment(AppStore.self) private var store
    let day: Day
    @State private var editing: VacationEditorTarget?

    var body: some View {
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(store.isVacation(on: day) ? "휴가 · 통계 제외" : "휴가 설정", systemImage: "sun.max")
                        .font(.headline)
                    Spacer()
                    Button("기간 추가") { editing = VacationEditorTarget(day: day) }
                        .buttonStyle(.borderless)
                }
                ForEach(store.vacations(on: day)) { period in
                    Button {
                        editing = VacationEditorTarget(day: day, period: period)
                    } label: {
                        HStack {
                            VacationPeriodLabel(period: period)
                            Spacer()
                            Text("수정·해제").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $editing) { VacationEditorSheet(target: $0) }
    }
}

struct VacationEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: VacationEditorTarget
    @State private var start: Date
    @State private var end: Date
    @State private var memo: String
    @State private var error: String?

    init(target: VacationEditorTarget) {
        self.target = target
        _start = State(initialValue: (target.period?.start ?? target.day).anchorDate)
        _end = State(initialValue: (target.period?.end ?? target.day).anchorDate)
        _memo = State(initialValue: target.period?.memo ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("시작일", selection: $start, displayedComponents: .date)
                    DatePicker("종료일", selection: $end, in: start..., displayedComponents: .date)
                    TextField("메모 (선택)", text: $memo, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("시작일과 종료일을 같게 선택하면 하루 휴가예요. 휴가를 해제하면 기존 체크가 다시 통계에 반영됩니다.")
                }
                if let error { Text(error).foregroundStyle(.red) }
                if let period = target.period {
                    Section {
                        Button("이 휴가 기간 해제", role: .destructive) {
                            if store.removeVacation(period) { dismiss() }
                            else { error = store.errorMessage }
                        }
                    } footer: {
                        Text("겹치는 다른 휴가 기간이 있으면 해당 날짜는 계속 휴가로 남아요.")
                    }
                }
            }
            .formStyle(.grouped)
            // 저장된 달력 날짜가 사용자의 시간대에 따라 하루 밀리지 않게 한다.
            .environment(\.timeZone, .gmt)
            .environment(\.calendar, Day.calendar)
            .navigationTitle(target.period == nil ? "휴가 추가" : "휴가 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if store.saveVacation(id: target.period?.id, start: Day(anchorDate: start),
                                              end: Day(anchorDate: end), memo: memo) { dismiss() }
                        else { error = store.errorMessage }
                    }
                }
            }
            .onChange(of: start) { _, value in if end < value { end = value } }
        }
        #if os(macOS)
        .frame(width: 500, height: 420)
        #endif
    }
}
