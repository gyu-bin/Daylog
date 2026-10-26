import Foundation

/// 시즌 아이콘(2026-10-26, 모든 사용자 무료). 날짜에 맞는 계절·명절이 있으면 그 시즌 의상을 입은 피오 아이콘을 쓰고,
/// 없으면 기본 아이콘을 쓴다. 의상을 사지 않아도 시즌 동안은 자동으로 적용된다(직접 고르는 건 산 의상만).
enum PioSeason: String, CaseIterable, Sendable {
    case spring, rainy, summer, autumn, halloween, christmas, winter, holiday

    /// 그 시즌에 입는 의상.
    var outfit: PioOutfitID {
        switch self {
        case .spring: .cherryBlossom
        case .rainy: .rainyDay
        case .summer: .summerVacation
        case .autumn: .autumn
        case .halloween: .halloween
        case .christmas: .christmas
        case .winter: .winter
        case .holiday: .hanbok
        }
    }
    var iconName: String { "AppIcon-\(outfit.rawValue)" }
    var previewAssetName: String { "pio_icon_preview_\(outfit.rawValue)" }
    var title: String {
        switch self {
        case .spring: "봄"
        case .rainy: "장마"
        case .summer: "여름"
        case .autumn: "가을"
        case .halloween: "할로윈"
        case .christmas: "크리스마스"
        case .winter: "겨울"
        case .holiday: "명절"
        }
    }

    /// 설날·추석 당일(양력). 앞뒤 이틀을 명절로 본다. 표가 끝난 해에는 명절 아이콘을 쓰지 않는다(다른 계절로 이어진다).
    static let lunarHolidays: [String] = [
        "2026-02-17", "2026-09-25", "2027-02-07", "2027-09-15", "2028-01-27", "2028-10-03",
        "2029-02-13", "2029-09-22", "2030-02-03", "2030-09-12", "2031-01-23", "2031-10-01",
    ]

    /// 그날의 시즌. 겹치면 명절 > 크리스마스 > 할로윈 > 계절 순이다. 3월 초와 5월~6월 중순은 기본 아이콘(nil).
    static func current(on date: Date = Date(), calendar: Calendar = .current) -> PioSeason? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        let today = calendar.startOfDay(for: date)
        for key in lunarHolidays {
            let p = key.split(separator: "-").compactMap { Int($0) }
            guard p.count == 3, let center = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { continue }
            if let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: center), to: today).day, abs(offset) <= 2 { return .holiday }
        }
        _ = year
        switch (month, day) {
        case (12, 1...25): return .christmas
        case (10, 17...31): return .halloween
        case (12, _), (1, _), (2, _): return .winter
        case (3, 15...), (4, _): return .spring
        case (6, 20...), (7, ...20): return .rainy
        case (7, _), (8, _): return .summer
        case (9, _), (10, _), (11, _): return .autumn
        default: return nil
        }
    }
}

/// 시즌 아이콘 자동 교체 설정(이 기기). 기본은 켜짐. 사용자가 아이콘을 직접 고르면 꺼진다.
enum PioSeasonalIconPreference {
    static let key = "pio.seasonalIcon.v1"
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool { defaults.object(forKey: key) as? Bool ?? true }
}
