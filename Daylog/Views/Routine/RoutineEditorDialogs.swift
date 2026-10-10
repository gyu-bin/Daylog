import SwiftUI

extension View {
    /// 루틴 관리 화면의 편집 시트, 이름 변경, 삭제 확인.
    func routineEditorDialogs(_ editor: RoutineEditorState) -> some View {
        modifier(RoutineEditorDialogs(editor: editor))
    }
}

private struct RoutineEditorDialogs: ViewModifier {
    @Environment(AppStore.self) private var store
    @Bindable var editor: RoutineEditorState

    func body(content: Content) -> some View {
        content
            .sheet(item: $editor.editing) { routine in
                RoutineEditSheet(routine: routine)
            }
            .alert("그룹 이름 변경", isPresented: $editor.renamingGroup.isPresent(), presenting: editor.renamingGroup) { group in
                TextField("그룹 이름", text: $editor.renameText)
                Button("저장") {
                    // 이름을 비우면 바꾸지 않는다.
                    let trimmed = editor.renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, trimmed != group.title {
                        store.updateGroup(group, title: trimmed)
                    }
                }
                Button("취소", role: .cancel) {}
            }
            .alert(
                "'\(editor.deletingGroup?.title ?? "")' 그룹을 삭제할까요?",
                isPresented: $editor.deletingGroup.isPresent(),
                presenting: editor.deletingGroup
            ) { group in
                Button("삭제", role: .destructive) {
                    store.deleteGroup(group)
                }
                Button("취소", role: .cancel) {}
            } message: { group in
                Text(RoutineDeletion.groupMessage(itemCount: store.routines.filter { $0.effectiveGroupID == group.id }.count))
            }
            .alert(
                "'\(editor.deletingRoutine?.title ?? "")' 항목을 삭제할까요?",
                isPresented: $editor.deletingRoutine.isPresent(),
                presenting: editor.deletingRoutine
            ) { routine in
                Button("삭제", role: .destructive) {
                    store.deleteRoutine(routine)
                }
                Button("취소", role: .cancel) {}
            } message: { _ in
                Text(RoutineDeletion.itemMessage)
            }
    }
}

/// 삭제 확인 문구. 삭제는 보관과 달리 목록으로 되돌릴 수 없다는 점과, 지난 기록은 남는다는 점을 알린다.
enum RoutineDeletion {
    static let itemMessage = "루틴 목록에서 사라지고 되돌릴 수 없어요. 지난 기록과 통계는 유지됩니다."

    static func groupMessage(itemCount: Int) -> String {
        itemCount == 0
            ? "되돌릴 수 없어요. 지난 기록과 통계는 유지됩니다."
            : "이 그룹의 루틴 \(itemCount)개도 함께 삭제되고 되돌릴 수 없어요. 지난 기록과 통계는 유지됩니다."
    }
}

extension Binding {
    /// 옵셔널 값이 있으면 true. false를 넣으면 값을 비운다.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { if !$0 { wrappedValue = nil } }
        )
    }
}
