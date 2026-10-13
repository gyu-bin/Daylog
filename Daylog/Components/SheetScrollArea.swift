import SwiftUI

/// 긴 시트 내용. macOS의 시트는 내용만큼 커지므로, 정해진 높이를 넘을 때만 안에서 스크롤한다.
/// iPhone·iPad의 시트는 틀이 이미 스크롤하므로 그대로 둔다.
struct SheetScrollArea<Content: View>: View {
    var maxHeight: CGFloat = 480
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if os(macOS)
        ViewThatFits(in: .vertical) {
            content()
            ScrollView {
                content().padding(.trailing, 10)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxHeight: maxHeight)
        #else
        content()
        #endif
    }
}
