import SwiftUI

/// 지난 식사 기록을 기간과 검색어로 찾아보는 화면. 분석이 아니라 조회다.
struct MealHistoryView: View {
    @Environment(AppStore.self) private var store
    let isWide: Bool

    @State private var days: [MealDay] = []
    @State private var nextOffset: Int?
    @State private var summary = MealSummary()
    /// 실제로 조회에 쓴 검색어. 입력이 잠시 멈춘 뒤에 반영한다.
    @State private var appliedQuery = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: Theme.spacing) {
            AdaptiveRow(isWide: isWide) {
                recordedDaysCard
                monthRateCard
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            periodPicker(selection: $store.mealPeriod)
                            searchField(text: $store.mealQuery)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            periodPicker(selection: $store.mealPeriod)
                            searchField(text: $store.mealQuery)
                        }
                    }

                    if days.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(days) { day in
                                MealDayRow(day: day, query: appliedQuery) {
                                    store.open(day.day)
                                }
                            }
                            if nextOffset != nil {
                                Button("이전 기록 더 보기") {
                                    loadMore()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                                // 목록 끝에 닿으면 알아서 이어 읽는다.
                                .onAppear(perform: loadMore)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            appliedQuery = store.mealQuery
            reload()
        }
        .onChange(of: store.mealPeriod) { reload() }
        .onChange(of: store.dataVersion) { reload() }
        // 글자를 칠 때마다 조회하지 않고, 입력이 0.25초 멈추면 한 번 조회한다.
        .task(id: store.mealQuery) {
            guard store.mealQuery != appliedQuery else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            appliedQuery = store.mealQuery
            reload()
        }
    }

    // MARK: - 조회

    private func reload() {
        let page = store.mealPage(period: store.mealPeriod, query: appliedQuery)
        days = page.days
        nextOffset = page.nextOffset
        summary = store.mealSummary(period: store.mealPeriod)
    }

    private func loadMore() {
        guard let offset = nextOffset else { return }
        let page = store.mealPage(period: store.mealPeriod, query: appliedQuery, offset: offset)
        let known = Set(days.map(\.day))
        days += page.days.filter { !known.contains($0.day) }
        nextOffset = page.nextOffset
    }

    // MARK: - 요약

    private var recordedDaysCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(symbol: "fork.knife", title: "식사 기록 일수", subtitle: "(\(store.mealPeriod.title))")
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(summary.recordedDays)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("일")
                        .font(.title3.weight(.semibold))
                }
                .foregroundStyle(GroupColor.orange.color)
                Text("아침·점심·저녁·간식 중 하나라도 적은 날이에요. 메모만 적은 날은 세지 않아요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var monthRateCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(symbol: "calendar", title: "이번 달 식사 기록률")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(summary.monthPercent.map { "\($0)%" } ?? "—")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(summary.monthPercent == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(GroupColor.blue.color))
                    if summary.monthElapsedDays > 0 {
                        Text("\(summary.monthElapsedDays)일 중 \(summary.monthRecordedDays)일")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Text("이번 달에 식사를 적은 날의 비율이에요(앱을 쓰기 시작한 날부터). 식단이나 영양을 평가하는 숫자가 아니에요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 필터

    private func periodPicker(selection: Binding<MealPeriod>) -> some View {
        Picker("기간", selection: selection) {
            ForEach(MealPeriod.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private func searchField(text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("식사 검색", text: text, prompt: Text("음식이나 메모로 검색 (예: 닭가슴살)"))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .accessibilityLabel("식사 기록 검색")
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 200, maxWidth: .infinity, minHeight: 28)
        .background(Theme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
    }

    @ViewBuilder
    private var emptyState: some View {
        if !appliedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyHint(
                symbol: "magnifyingglass",
                message: "\(store.mealPeriod.title) 기록에서 \"\(appliedQuery)\"을(를) 찾지 못했어요.\n기간을 넓히거나 다른 말로 찾아보세요."
            )
        } else {
            EmptyHint(
                symbol: "fork.knife",
                message: "\(store.mealPeriod.title)에 적은 식사 기록이 없어요.\n대시보드에서 오늘 식사를 적으면 여기에 쌓여요."
            )
        }
    }
}

/// 하루치 식사 기록 한 칸.
private struct MealDayRow: View {
    let day: MealDay
    let query: String
    let open: () -> Void

    private var meals: [(label: String, text: String, color: Color)] {
        [
            ("아침", day.breakfast, .orange),
            ("점심", day.lunch, .yellow),
            ("저녁", day.dinner, .indigo),
            ("간식", day.snack, .teal),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(day.day.shortTitle) \(day.day.weekdaySymbol)요일")
                    .font(.headline)
                    .monospacedDigit()
                Text(String(day.day.year))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Spacer()
                Button("해당 날짜 열기", action: open)
                    .controlSize(.small)
                    .accessibilityLabel("\(day.day.shortTitle) 기록 열기")
                    .help("대시보드에서 이 날짜의 루틴과 식사를 보고 고칩니다.")
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(meals, id: \.label) { meal in
                    line(label: meal.label, text: meal.text, color: meal.color)
                }
                if !MealDay.isBlank(day.memo) {
                    line(label: "메모", text: day.memo, color: Theme.accent)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.track.opacity(0.45), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func line(label: String, text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.callout.weight(.semibold))
            }
            .frame(width: 52, alignment: .leading)

            if MealDay.isBlank(text) {
                // 비워 둔 칸. 사용자가 직접 "없음"이라고 적은 경우는 그 글자를 그대로 보여 준다.
                Text("미기록")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text(highlighted(text))
                    .font(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 검색어와 일치하는 부분을 굵게 표시한다.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return attributed }
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let found = attributed[searchRange].range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[found].font = .callout.bold()
            attributed[found].backgroundColor = GroupColor.yellow.color.opacity(0.35)
            searchRange = found.upperBound..<attributed.endIndex
        }
        return attributed
    }
}
