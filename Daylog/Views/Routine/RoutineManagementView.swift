import SwiftUI

/// 루틴 추가·수정·순서 변경·보관·복원. 변경은 오늘과 미래에만 적용되고 과거 기록은 그대로다.
struct RoutineManagementView: View {
    @Environment(AppStore.self) private var store
    @State private var draft = ""
    @State private var showsArchived = false
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        let active = store.activeRoutines
        let archived = store.archivedRoutines

        // List를 쓰면 행 안의 입력 칸이 첫 클릭에 바로 편집되지 않아서, 스크롤 뷰에 직접 배치한다.
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                VStack(alignment: .leading, spacing: 4) {
                    PageTitle(title: "루틴 관리")
                    Text("변경한 내용은 오늘부터 적용되고, 지난 날짜의 기록은 바뀌지 않아요. 왼쪽 손잡이를 끌거나 화살표로 순서를 바꿀 수 있어요.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Card {
                    VStack(alignment: .leading, spacing: 0) {
                        if active.isEmpty {
                            Text(archived.isEmpty
                                 ? "아직 루틴이 없어요. 아래에 이름을 적고 Enter를 눌러 보세요."
                                 : "사용 중인 루틴이 없어요. 새로 추가하거나 보관된 루틴을 복원하세요.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                            Divider()
                        }
                        ForEach(active) { routine in
                            RoutineEditorRow(
                                routine: routine,
                                canMoveUp: routine.id != active.first?.id,
                                canMoveDown: routine.id != active.last?.id,
                                onTitleSubmitted: { addFieldFocused = true }
                            )
                            Divider()
                        }
                        addRow
                    }
                }

                if !archived.isEmpty {
                    Card {
                        DisclosureGroup(isExpanded: $showsArchived) {
                            VStack(spacing: 0) {
                                ForEach(archived) { routine in
                                    Divider()
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(routine.title)
                                            Text(Weekdays.summary(routine.weekdays))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("복원") {
                                            store.setArchived(routine, false)
                                        }
                                        .accessibilityLabel("\(routine.title) 복원")
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            Text("보관된 루틴 \(archived.count)개")
                                .font(.headline)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        CardHeader(symbol: "target", title: "달성한 날 기준값")
                        ThresholdControl()
                        Text("바꾸면 연속 달성일, 최장 연속 달성일, 달성 표시가 바로 다시 계산돼요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Theme.pagePadding)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            TextField("새 루틴", text: $draft, prompt: Text("새 루틴 이름을 적고 Enter"))
                .textFieldStyle(.plain)
                .focused($addFieldFocused)
                .onSubmit(addRoutine)
                .accessibilityLabel("새 루틴 이름")
            Button("추가", action: addRoutine)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.top, 12)
    }

    /// Enter 후에도 포커스를 유지해 다음 루틴을 이어서 입력할 수 있게 한다.
    private func addRoutine() {
        if store.addRoutine(title: draft) {
            draft = ""
        }
        addFieldFocused = true
    }
}
