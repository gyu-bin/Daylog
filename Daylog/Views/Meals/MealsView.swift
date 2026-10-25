import SwiftUI

/// 식사 기록: 고른 날짜의 식사를 적고, 지난 식사를 찾아본다.
/// 대시보드의 식사 카드와 같은 기록(DayRecord)을 쓰므로 어느 쪽에서 적어도 같다.
struct MealsView: View {
    @Environment(AppStore.self) private var store

    private static let inputID = "meal-input"

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 880
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacing) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center) {
                                title
                                Spacer(minLength: 16)
                                DateNavigator()
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                title
                                DateNavigator()
                            }
                        }

                        MealCard()
                            .id(Self.inputID)

                        // 지난 날짜를 고르면 위의 입력 카드가 그 날짜로 바뀐다.
                        MealHistoryView(isWide: isWide) { day in
                            store.select(day)
                            withAnimation { scroll.scrollTo(Self.inputID, anchor: .top) }
                        }
                    }
                    .pagePadding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private var title: some View {
        PageTitle(title: "식사 기록", subtitle: "적으면 자동으로 저장돼요. 지난 날짜도 고칠 수 있어요.", pio: PioLines.meals())
    }
}
