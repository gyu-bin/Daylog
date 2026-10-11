import SwiftUI

/// 지난 식사 기록을 기간과 검색어로 찾아보는 화면. 분석이 아니라 조회다.
struct MealHistoryView: View {
    @Environment(AppStore.self) private var store
    let isWide: Bool
    /// 지난 날짜를 골랐을 때 할 일(그 날짜의 식사를 열어 고친다).
    let onOpen: (Day) -> Void

    @State private var days: [MealDay] = []
    @State private var nextOffset: Int?
    @State private var summary = MealSummary()
    /// 실제로 조회에 쓴 검색어. 입력이 잠시 멈춘 뒤에 반영한다.
    @State private var appliedQuery = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            MealSummaryTiles(summary: summary, periodTitle: store.mealPeriod.title, isWide: isWide)

            if isWide {
                HStack(alignment: .top, spacing: Theme.spacing) {
                    timeline
                    MealCalendarCard(onOpen: onOpen).frame(width: 300)
                }
            } else {
                MealCalendarCard(onOpen: onOpen)
                timeline
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

    // MARK: - 타임라인

    private var timeline: some View {
        @Bindable var store = store
        return Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(symbol: "clock.arrow.circlepath", title: "식사 타임라인", tint: Theme.mealTint) {
                    if !days.isEmpty {
                        Text("\(days.count)일\(nextOffset == nil ? "" : "+")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

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
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(days) { day in
                            MealTimelineRow(day: day, query: appliedQuery, isLast: day.id == days.last?.id && nextOffset == nil) {
                                onOpen(day.day)
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

    private func periodPicker(selection: Binding<MealPeriod>) -> some View {
        Picker("기간", selection: selection) {
            ForEach(MealPeriod.allCases) { period in
                Text(period.shortTitle).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("식사 기록 기간")
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
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(searchFocused ? Theme.mealTint.opacity(0.7) : .clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        if !appliedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyHint(
                symbol: "magnifyingglass",
                message: "\(store.mealPeriod.title) 기록에서 \"\(appliedQuery)\"을(를) 찾지 못했어요.\n기간을 넓히거나 다른 말로 찾아보세요.",
                tint: Theme.mealTint
            )
        } else {
            EmptyHint(
                symbol: "fork.knife",
                message: "\(store.mealPeriod.title)에 적은 식사 기록이 없어요.\n위에서 식사를 적으면 여기에 쌓여요.",
                tint: Theme.mealTint,
                actionTitle: "오늘 식사 적기"
            ) {
                onOpen(store.today)
            }
        }
    }
}

extension MealPeriod {
    /// 기간 선택 버튼에 쓰는 짧은 이름.
    var shortTitle: String {
        switch self {
        case .week: return "7일"
        case .month: return "30일"
        case .all: return "전체"
        }
    }
}

/// 식사 기록 요약 두 칸. 식사 기록 화면과 통계 화면이 같이 쓴다.
struct MealSummaryTiles: View {
    let summary: MealSummary
    let periodTitle: String
    let isWide: Bool

    var body: some View {
        AdaptiveRow(isWide: isWide) {
            StatTile(
                symbol: "fork.knife", title: "식사 기록 일수", color: .coral,
                value: "\(summary.recordedDays)", unit: "일",
                caption: "\(periodTitle) · 한 끼라도 적은 날"
            )
            StatTile(
                symbol: "calendar", title: "이번 달 식사 기록률", color: .blue,
                value: summary.monthPercent.map { "\($0)%" },
                caption: summary.monthElapsedDays > 0
                    ? "\(summary.monthElapsedDays)일 중 \(summary.monthRecordedDays)일"
                    : "식사를 적기 시작하면 표시돼요."
            )
        }
    }
}
