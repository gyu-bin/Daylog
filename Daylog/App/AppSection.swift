import Foundation

extension AppStore {
    /// 사이드바 메뉴.
    enum Section: String, CaseIterable, Identifiable {
        case dashboard, routines, statistics, settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: return "대시보드"
            case .routines: return "루틴 관리"
            case .statistics: return "통계"
            case .settings: return "설정"
            }
        }

        var symbol: String {
            switch self {
            case .dashboard: return "house"
            case .routines: return "list.bullet.rectangle"
            case .statistics: return "chart.bar.xaxis"
            case .settings: return "gearshape"
            }
        }
    }
}
