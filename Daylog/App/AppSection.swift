import Foundation

extension AppStore {
    /// 앱의 메뉴. macOS와 iPad는 사이드바에 모두 보이고, iPhone은 캘린더를 뺀 다섯 개를 아래 탭에 둔다.
    enum Section: String, CaseIterable, Identifiable {
        case dashboard, routines, meals, statistics, calendar, settings

        var id: String { rawValue }

        /// 사이드바와 탭에 쓰는 짧은 이름.
        var title: String {
            switch self {
            case .dashboard: return "오늘"
            case .routines: return "루틴"
            case .meals: return "식사 기록"
            case .statistics: return "통계"
            case .calendar: return "캘린더"
            case .settings: return "설정"
            }
        }

        var symbol: String {
            switch self {
            case .dashboard: return "house"
            case .routines: return "checklist"
            case .meals: return "fork.knife"
            case .statistics: return "chart.bar"
            case .calendar: return "calendar"
            case .settings: return "gearshape"
            }
        }

        /// iPhone의 아래 탭에 두는 메뉴. 캘린더는 통계 화면과 날짜 이동에서 들어간다.
        static let phoneTabs: [Section] = [.dashboard, .routines, .meals, .statistics, .settings]
    }
}
