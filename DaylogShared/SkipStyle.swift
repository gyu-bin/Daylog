import SwiftUI

/// "건너뛰기" 상태의 아이콘과 색. 앱의 체크 행·통계와 위젯이 같은 모양을 쓴다.
/// 완료(그룹 색 체크)·미완료(빈 칸)와 겹치지 않게 회색 "—"와 "건너뜀" 글자로 구분한다.
enum SkipStyle {
    /// 회색 "—". 한 것도 안 한 것도 아니라 "쉬었다"는 뜻이라 강조색을 쓰지 않는다(노란색은 경고처럼 읽혔다).
    static let symbol = "minus"
    static let color = Color.gray
    static let ink = Color.secondary
    static let wash = Color.gray.opacity(0.18)
    static let label = "건너뜀"
}

/// 체크 칸 자리에 놓는 건너뛰기 표시. 체크 칸과 같은 크기의 둥근 네모다.
struct SkipMark: View {
    var size: CGFloat = 19

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(SkipStyle.wash)
            .overlay(
                Image(systemName: SkipStyle.symbol)
                    .font(.system(size: size * 0.47, weight: .bold))
                    .foregroundStyle(SkipStyle.ink)
            )
            .frame(width: size * 0.86, height: size * 0.86)
            .frame(width: size, height: size)
    }
}
