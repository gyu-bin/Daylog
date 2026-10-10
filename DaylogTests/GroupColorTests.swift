import Foundation
import Testing
@testable import Daylog

/// TEST 20: 색 팔레트. 색만으로 구분하지 않지만(이름·숫자 병기), 색끼리도 구별돼야 한다.
struct GroupColorTests {
    private func distance(_ lhs: GroupColor.RGB, _ rhs: GroupColor.RGB) -> Double {
        let red = lhs.red - rhs.red, green = lhs.green - rhs.green, blue = lhs.blue - rhs.blue
        return (red * red + green * green + blue * blue).squareRoot()
    }

    @Test func colorsAreDistinctInBothAppearances() {
        for isDark in [false, true] {
            let colors = GroupColor.allCases.map { $0.rgb(isDark: isDark) }
            for (index, color) in colors.enumerated() {
                for other in colors[(index + 1)...] {
                    #expect(distance(color, other) > 0.12)
                }
            }
        }
    }

    @Test func darkVariantsStandOutOnDarkBackground() {
        // 다크 모드의 카드 배경(약 #1E1E1E)과의 명도 대비가 3:1 이상이어야 아이콘·막대가 보인다.
        let background = GroupColor.RGB(red: 0.12, green: 0.12, blue: 0.12).luminance
        for color in GroupColor.allCases {
            let luminance = color.rgb(isDark: true).luminance
            #expect((luminance + 0.05) / (background + 0.05) >= 3)
        }
    }

    @Test func unknownKeyFallsBackToDefault() {
        #expect(GroupColor(key: "teal-from-the-future") == .green)
        #expect(GroupColor(key: "orange") == .orange)
        #expect(GroupColor.allCases.count == 7)
    }
}
