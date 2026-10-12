import Foundation

/// 원격에서 받는 모바일 UI 설정 파일(JSON)의 모양. iPhone·iPad 전용.
///
/// 이 파일은 신뢰할 수 없는 입력으로 다룬다. 앱에 미리 만들어 둔 선택지 가운데 무엇을 쓸지만 정하고,
/// 코드·화면·데이터 모델·동기화 동작은 바꾸지 못한다. 모르는 칸은 읽지 않고, 범위를 벗어난 값은 버린다.
/// 형식과 게시 방법은 docs/MOBILE_OTA.md.
struct MobileUIConfig: Decodable, Equatable {
    var schemaVersion: Int
    var configVersion: Int
    var minimumSupportedAppBuild: Int
    var updatedAt: String
    var dashboard: Dashboard?
    var appearance: Appearance?
    var content: Content?
    var features: [String: Bool]?

    struct Dashboard: Decodable, Equatable {
        var defaultCardOrder: [String]?
        var defaultHiddenCards: [String]?
        var layoutStyle: String?
        var cardSpacing: Double?
        var cardPadding: Double?
    }

    struct Appearance: Decodable, Equatable {
        var accent: String?
        var cardStyle: String?
    }

    struct Content: Decodable, Equatable {
        var onboarding: [String: String]?
        var dashboard: [String: String]?
        var emptyStates: [String: String]?
    }

    /// 이 앱이 읽을 수 있는 형식 번호.
    static let supportedSchemaVersion = 1
    /// 받아들이는 파일의 최대 크기(바이트). 정상 파일은 2KB 안팎이다.
    static let maximumSize = 64 * 1024
}

enum MobileUIConfigError: Error, Equatable {
    case tooLarge(Int)
    case notJSON
    case unsupportedSchema(Int)
    case requiresNewerApp(minimumBuild: Int)
    case invalidHeader

    /// 설정 화면에 보여 주는 짧은 설명.
    var message: String {
        switch self {
        case .tooLarge: return "받은 설정이 너무 커서 쓰지 않았어요."
        case .notJSON: return "받은 설정을 읽을 수 없어 쓰지 않았어요."
        case .unsupportedSchema: return "이 앱 버전이 읽을 수 없는 형식의 설정이에요."
        case .requiresNewerApp: return "더 새로운 앱 버전용 설정이라 쓰지 않았어요."
        case .invalidHeader: return "설정의 버전 정보가 올바르지 않아 쓰지 않았어요."
        }
    }
}

/// 화면이 실제로 쓰는 값. 원격 설정에서 유효한 것만 골라 담고, 나머지는 앱에 내장된 기본값이다.
struct MobileUISettings: Equatable, Sendable {
    /// 원격 설정의 버전. 내장 기본값이면 0.
    var configVersion = 0
    var updatedAt = ""

    // 대시보드
    /// iPhone의 기본 카드 순서(사용자가 배치를 바꾸지 않았을 때만 쓴다). nil이면 내장 순서.
    var defaultCardOrder: [String]?
    /// 처음에 숨겨 두는 카드(사용자가 배치를 바꾸지 않았을 때만 쓴다). nil이면 내장값.
    var defaultHiddenCards: [String]?
    var cardSpacing: Double = Self.builtInSpacing
    /// 카드 안쪽 여백. 카드가 여백을 따로 정하지 않았을 때 쓴다.
    var cardPadding: Double = Self.builtInPadding

    // 디자인
    var accent: GroupColor = .mint
    var cardStyle: CardStyle = .bordered

    // 문구(키 → 글). 없는 키는 내장 문구.
    var text: [TextKey: String] = [:]

    // 기능 표시
    var showsGreetingIcon = true
    var showsOnboardingNotificationGuide = true

    static let builtIn = MobileUISettings()
    static let builtInSpacing: Double = 16
    static let builtInPadding: Double = 18

    enum CardStyle: String, CaseIterable, Sendable {
        /// 옅은 테두리, 그림자 없음(지금의 모습).
        case bordered
        /// 테두리 없이 옅은 그림자.
        case soft
        /// 테두리도 그림자도 없는 평평한 면.
        case flat
    }

    /// 미리 정해 둔 간격 묶음. `cardSpacing`·`cardPadding`을 따로 적으면 그 값이 우선한다.
    enum LayoutStyle: String, CaseIterable, Sendable {
        case standard, compact, airy

        var spacing: Double {
            switch self {
            case .standard: return 16
            case .compact: return 12
            case .airy: return 20
            }
        }

        var padding: Double {
            switch self {
            case .standard: return 18
            case .compact: return 14
            case .airy: return 20
            }
        }
    }

    /// 원격에서 바꿀 수 있는 문구. 여기 없는 문구는 바꿀 수 없다.
    enum TextKey: String, CaseIterable, Sendable {
        case onboardingIntroTitle = "onboarding.introTitle"
        case onboardingNotificationTitle = "onboarding.notificationTitle"
        case onboardingNotificationBody = "onboarding.notificationBody"
        case dashboardGreeting = "dashboard.greeting"
        case emptyNoRoutinesToday = "emptyStates.noRoutinesToday"
        case emptyNoRoutinesYet = "emptyStates.noRoutinesYet"

        var builtIn: String {
            switch self {
            case .onboardingIntroTitle: return "작은 루틴부터, 나만의 하루를."
            case .onboardingNotificationTitle: return "루틴 시간을 놓치지 마세요"
            case .onboardingNotificationBody: return "설정한 시간에 Daylog가 알려드려요."
            case .dashboardGreeting: return "오늘도 좋은 하루예요"
            case .emptyNoRoutinesToday: return "오늘은 예정된 루틴이 없어요."
            case .emptyNoRoutinesYet: return "아직 등록된 루틴이 없어요."
            }
        }

        /// 글자 수 한도. 화면의 자리에 맞춘 값이다.
        var maximumLength: Int {
            switch self {
            case .onboardingIntroTitle, .onboardingNotificationTitle, .dashboardGreeting: return 24
            case .onboardingNotificationBody, .emptyNoRoutinesToday, .emptyNoRoutinesYet: return 40
            }
        }
    }

    func string(_ key: TextKey) -> String { text[key] ?? key.builtIn }

    static let spacingRange: ClosedRange<Double> = 8...24
    static let paddingRange: ClosedRange<Double> = 10...24
    /// 강조 색으로 허용하는 색. 노랑은 흰 글자와 대비가 모자라 뺐다.
    static let allowedAccents: [GroupColor] = [.mint, .green, .blue, .purple, .coral, .orange]
    /// 원격에서 켜고 끌 수 있는 표시. 여기 없는 이름은 무시한다.
    static let knownFeatures = ["greetingIcon", "onboardingNotificationGuide"]
}

extension MobileUIConfig {
    /// 받은 바이트를 검사해 설정으로 읽는다. 크기 → JSON → 형식 번호 → 앱 빌드 → 머리말 값 순서로 본다.
    static func decode(_ data: Data, appBuild: Int) throws -> MobileUIConfig {
        guard data.count <= maximumSize else { throw MobileUIConfigError.tooLarge(data.count) }
        // 형식 번호만 먼저 읽는다: 모르는 형식의 나머지 칸은 해석하지 않는다.
        struct Header: Decodable { var schemaVersion: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw MobileUIConfigError.notJSON }
        guard header.schemaVersion == supportedSchemaVersion else {
            throw MobileUIConfigError.unsupportedSchema(header.schemaVersion)
        }
        guard let config = try? JSONDecoder().decode(MobileUIConfig.self, from: data) else { throw MobileUIConfigError.notJSON }
        guard config.configVersion >= 1, config.minimumSupportedAppBuild >= 1, config.updatedAt.count <= 40 else {
            throw MobileUIConfigError.invalidHeader
        }
        guard appBuild >= config.minimumSupportedAppBuild else {
            throw MobileUIConfigError.requiresNewerApp(minimumBuild: config.minimumSupportedAppBuild)
        }
        return config
    }

    /// 유효한 값만 골라 화면이 쓸 설정으로 만든다. 허용 목록에 없거나 범위를 벗어난 값은 내장 기본값으로 둔다
    /// (한 칸이 틀렸다고 파일 전체를 버리지는 않는다. 게시 전 검사는 Tools/mobile-config.sh가 엄격하게 한다).
    func resolved() -> MobileUISettings {
        var settings = MobileUISettings()
        settings.configVersion = configVersion
        settings.updatedAt = updatedAt

        if let dashboard {
            let known = Set(DashboardCard.allCases.map(\.rawValue))
            if let order = dashboard.defaultCardOrder {
                let cards = order.filter(known.contains)
                // 같은 카드가 두 번 있거나 아는 카드가 하나도 없으면 쓰지 않는다.
                if !cards.isEmpty, Set(cards).count == cards.count { settings.defaultCardOrder = cards }
            }
            if let hidden = dashboard.defaultHiddenCards {
                // 루틴 카드는 숨길 수 없다.
                settings.defaultHiddenCards = Array(Set(hidden.filter(known.contains)).subtracting([DashboardCard.routines.rawValue])).sorted()
            }
            if let style = dashboard.layoutStyle.flatMap(MobileUISettings.LayoutStyle.init(rawValue:)) {
                settings.cardSpacing = style.spacing
                settings.cardPadding = style.padding
            }
            if let spacing = dashboard.cardSpacing, MobileUISettings.spacingRange.contains(spacing) { settings.cardSpacing = spacing }
            if let padding = dashboard.cardPadding, MobileUISettings.paddingRange.contains(padding) { settings.cardPadding = padding }
        }

        if let appearance {
            if let accent = appearance.accent.flatMap(GroupColor.init(rawValue:)), MobileUISettings.allowedAccents.contains(accent) {
                settings.accent = accent
            }
            if let style = appearance.cardStyle.flatMap(MobileUISettings.CardStyle.init(rawValue:)) { settings.cardStyle = style }
        }

        if let content {
            let groups = ["onboarding": content.onboarding, "dashboard": content.dashboard, "emptyStates": content.emptyStates]
            for key in MobileUISettings.TextKey.allCases {
                let parts = key.rawValue.split(separator: ".").map(String.init)
                guard parts.count == 2, let value = groups[parts[0]]??[parts[1]], let clean = Self.cleanText(value, limit: key.maximumLength)
                else { continue }
                settings.text[key] = clean
            }
        }

        if let features {
            if let value = features["greetingIcon"] { settings.showsGreetingIcon = value }
            if let value = features["onboardingNotificationGuide"] { settings.showsOnboardingNotificationGuide = value }
        }
        return settings
    }

    /// 문구는 한 줄의 글자만 받는다: 앞뒤 공백을 떼고, 줄바꿈·제어 문자가 있거나 비었거나 너무 길면 쓰지 않는다.
    static func cleanText(_ value: String, limit: Int) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= limit,
              !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) })
        else { return nil }
        return trimmed
    }
}
