import Foundation

extension AppStore {
    /// 앱의 메뉴. macOS와 iPad는 사이드바에 모두 보이고, iPhone은 캘린더·휴가·템플릿을 뺀 다섯 개를 아래 탭에 둔다.
    /// 템플릿은 기존 메뉴의 순서와 단축키 번호가 바뀌지 않게 설정 바로 앞에 둔다.
    enum Section: String, CaseIterable, Identifiable {
        case dashboard, routines, meals, statistics, calendar, vacation, templates, wardrobe, settings

        var id: String { rawValue }

        /// 사이드바와 탭에 쓰는 짧은 이름.
        var title: String {
            switch self {
            case .dashboard: return "오늘"
            case .routines: return "루틴"
            case .meals: return "식사 기록"
            case .statistics: return "통계"
            case .calendar: return "캘린더"
            case .vacation: return "휴가"
            case .templates: return "템플릿"
            case .wardrobe: return "피오 옷장"
            case .settings: return "설정"
            }
        }

        var symbol: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .routines: return "checklist"
            case .meals: return "fork.knife"
            case .statistics: return "chart.bar"
            case .calendar: return "calendar"
            case .vacation: return "beach.umbrella"
            case .templates: return "rectangle.stack"
            case .wardrobe: return "tshirt"
            case .settings: return "gearshape"
            }
        }

        /// iPhone의 아래 탭에 두는 메뉴. 캘린더는 통계 화면에서, 휴가는 오늘 화면의 휴가 카드와 설정에서,
        /// 템플릿은 루틴 탭의 [템플릿] 단추로 들어간다.
        static let phoneTabs: [Section] = [.dashboard, .routines, .meals, .statistics, .settings]

        /// Keep the existing numbered shortcuts when adding the wardrobe.
        var shortcutNumber: Int {
            switch self {
            case .wardrobe: return 9
            case .settings: return 8
            default: return Self.allCases.firstIndex(of: self)! + 1
            }
        }

        @MainActor var isAvailable: Bool {
            guard self == .wardrobe else { return true }
            return PioCharacter.isEnabled || PioWardrobeStore.outfitTestingEnabled(arguments: ProcessInfo.processInfo.arguments)
        }
    }
}
