import SwiftUI

/// "건너뛰기" 상태의 아이콘과 색. 앱의 체크 행·통계와 위젯이 같은 모양을 쓴다.
/// 완료(그룹 색 체크)·미완료(빈 칸)와 겹치지 않게 노랑과 "다음으로 넘기기" 기호로 구분한다.
enum SkipStyle {
    static let symbol = "forward.end.fill"
    static let color = GroupColor.yellow.color
    static let ink = GroupColor.yellow.ink
    static let wash = GroupColor.yellow.color.opacity(0.2)
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
