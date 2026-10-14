import Foundation
import Testing
@testable import Daylog

/// 원격 UI 설정: 형식 검사, 허용 목록, 캐시·오프라인·거부, 사용자 배치 우선.
@MainActor
struct MobileUIConfigTests {
    private func json(_ overrides: [String: Any] = [:], remove: [String] = []) -> Data {
        var object: [String: Any] = [
            "schemaVersion": 1, "configVersion": 2, "minimumSupportedAppBuild": 4, "updatedAt": "2026-10-12T12:00:00Z",
            "dashboard": ["layoutStyle": "compact", "defaultHiddenCards": ["calendar", "trend"]],
            "appearance": ["accent": "blue", "cardStyle": "soft"],
            "content": ["dashboard": ["greeting": "오늘 하루도 가볍게"]],
            "features": ["greetingIcon": false],
        ]
        for (key, value) in overrides { object[key] = value }
        for key in remove { object[key] = nil }
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    // MARK: - 형식과 허용 목록

    @Test func validConfigResolvesToAllowedValuesOnly() throws {
        let settings = try MobileUIConfig.decode(json(), appBuild: 5).resolved()
        #expect(settings.configVersion == 2)
        #expect(settings.cardSpacing == 12 && settings.cardPadding == 14)
        #expect(settings.accent == .blue && settings.cardStyle == .soft)
        #expect(settings.string(.dashboardGreeting) == "오늘 하루도 가볍게")
        // 적지 않은 문구는 내장 문구다.
        #expect(settings.string(.emptyNoRoutinesYet) == MobileUISettings.TextKey.emptyNoRoutinesYet.builtIn)
        #expect(settings.defaultHiddenCards == ["calendar", "trend"])
        #expect(settings.defaultCardOrder == nil)
        #expect(!settings.showsGreetingIcon && settings.showsOnboardingNotificationGuide)
    }

    @Test func malformedOversizedOrIncompatibleFilesAreRejected() {
        #expect(throws: MobileUIConfigError.notJSON) { try MobileUIConfig.decode(Data("{oops".utf8), appBuild: 5) }
        #expect(throws: MobileUIConfigError.notJSON) { try MobileUIConfig.decode(Data("[1,2]".utf8), appBuild: 5) }
        #expect(throws: MobileUIConfigError.unsupportedSchema(2)) { try MobileUIConfig.decode(json(["schemaVersion": 2]), appBuild: 5) }
        #expect(throws: MobileUIConfigError.requiresNewerApp(minimumBuild: 9)) {
            try MobileUIConfig.decode(json(["minimumSupportedAppBuild": 9]), appBuild: 5)
        }
        #expect(throws: MobileUIConfigError.invalidHeader) { try MobileUIConfig.decode(json(["configVersion": 0]), appBuild: 5) }
        #expect(throws: MobileUIConfigError.notJSON) { try MobileUIConfig.decode(json(remove: ["updatedAt"]), appBuild: 5) }
        let huge = Data(repeating: 0x20, count: MobileUIConfig.maximumSize + 1)
        #expect(throws: MobileUIConfigError.tooLarge(huge.count)) { try MobileUIConfig.decode(huge, appBuild: 5) }
    }

    @Test func outOfRangeAndUnknownValuesFallBackToBuiltInDefaults() throws {
        let data = json([
            "dashboard": ["cardSpacing": 400, "cardPadding": -3, "layoutStyle": "huge",
                          "defaultCardOrder": ["routines", "routines"], "defaultHiddenCards": ["routines", "nope", "trend"]],
            "appearance": ["accent": "yellow", "cardStyle": "neon"],
            "content": ["dashboard": ["greeting": String(repeating: "가", count: 200)],
                        "emptyStates": ["noRoutinesYet": "두 줄\n안 됨"],
                        "onboarding": ["introTitle": "   ", "unknownKey": "무시"]],
            "features": ["runScript": true, "downloadCode": true],
        ])
        let settings = try MobileUIConfig.decode(data, appBuild: 5).resolved()
        #expect(settings.cardSpacing == MobileUISettings.builtInSpacing)
        #expect(settings.cardPadding == MobileUISettings.builtInPadding)
        #expect(settings.accent == .mint && settings.cardStyle == .bordered)
        #expect(settings.text.isEmpty)
        // 같은 카드를 두 번 적은 순서는 쓰지 않는다. 루틴 카드는 숨길 수 없고, 모르는 카드는 무시한다.
        #expect(settings.defaultCardOrder == nil)
        #expect(settings.defaultHiddenCards == ["trend"])
        // 모르는 기능 표시는 아무 일도 하지 않는다.
        #expect(settings.showsGreetingIcon && settings.showsOnboardingNotificationGuide)
    }

    @Test func explicitSpacingOverridesTheLayoutPresetWithinRange() throws {
        let data = json(["dashboard": ["layoutStyle": "airy", "cardSpacing": 10, "cardPadding": 24]])
        let settings = try MobileUIConfig.decode(data, appBuild: 5).resolved()
        #expect(settings.cardSpacing == 10 && settings.cardPadding == 24)
        #expect(MobileUISettings.LayoutStyle.allCases.allSatisfy {
            MobileUISettings.spacingRange.contains($0.spacing) && MobileUISettings.paddingRange.contains($0.padding)
        })
    }

    @Test func splashDurationIsTakenOnlyWithinItsRange() throws {
        // 적지 않으면 기본값(1.5초).
        #expect(try MobileUIConfig.decode(json(), appBuild: 5).resolved().splashDuration == 1.5)
        for (value, expected) in [(0.5, 0.5), (1.2, 1.2), (2.0, 2.0), (0.4, 1.5), (2.5, 1.5), (-1, 1.5), (600, 1.5)] {
            let settings = try MobileUIConfig.decode(json(["splash": ["duration": value]]), appBuild: 5).resolved()
            #expect(settings.splashDuration == expected)
        }
        // 숫자가 아니면 파일을 읽지 못한 것으로 보고 쓰던 설정을 둔다(게시 전 검사가 막는다).
        #expect(throws: MobileUIConfigError.notJSON) { try MobileUIConfig.decode(json(["splash": ["duration": "fast"]]), appBuild: 5) }
        // 모르는 칸은 무시한다.
        #expect(try MobileUIConfig.decode(json(["splash": ["sound": true]]), appBuild: 5).resolved().splashDuration == 1.5)
    }

    @Test func textIsOneCleanLineWithinTheLimit() {
        #expect(MobileUIConfig.cleanText("  안녕하세요  ", limit: 10) == "안녕하세요")
        #expect(MobileUIConfig.cleanText("", limit: 10) == nil)
        #expect(MobileUIConfig.cleanText("열한 글자가 넘는 문구입니다", limit: 10) == nil)
        #expect(MobileUIConfig.cleanText("줄\n바꿈", limit: 10) == nil)
        #expect(MobileUIConfig.cleanText("탭\t문자", limit: 10) == nil)
    }

    @Test func onlyHTTPSAddressesAreAllowedAndChannelsAreSeparate() throws {
        #expect(MobileUIConfigChannel.isAllowed(try #require(URL(string: MobileUIConfigChannel.production))))
        #expect(MobileUIConfigChannel.isAllowed(try #require(URL(string: MobileUIConfigChannel.development))))
        #expect(MobileUIConfigChannel.production != MobileUIConfigChannel.development)
        #expect(!MobileUIConfigChannel.isAllowed(try #require(URL(string: "http://github.com/gyu-bin/Daylog/x.json"))))
        #expect(!MobileUIConfigChannel.isAllowed(try #require(URL(string: "https://user:pw@github.com/x.json"))))
        #expect(!MobileUIConfigChannel.isAllowed(try #require(URL(string: "file:///tmp/x.json"))))
        #expect(!MobileUIConfigChannel.isAllowed(try #require(URL(string: "http://192.168.0.5:8766/mobile-ui.json"))))
    }

    @Test func repositoryConfigFilesPassTheAppDecoderAndMatchBuiltInDefaults() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for name in ["mobile-ui.json", "mobile-ui.dev.json"] {
            let data = try Data(contentsOf: root.appendingPathComponent("RemoteConfig/\(name)"))
            let config = try MobileUIConfig.decode(data, appBuild: 4)
            var settings = config.resolved()
            // 저장소에 둔 기본 설정은 앱의 내장 기본값과 같은 화면을 낸다(게시해도 달라지는 것이 없다).
            // 설정 파일에는 나중에 생긴 카드(이번 주의 성장)가 없다. 앱이 그 카드를 내장 순서의 자리에 끼워 넣는다.
            #expect(DashboardCard.remoteOrder(settings.defaultCardOrder ?? []) == DashboardCard.defaultOrder(phone: true))
            #expect(Set(settings.defaultHiddenCards ?? []) == Set(DashboardCard.defaultHidden.map(\.rawValue)))
            settings.configVersion = 0; settings.updatedAt = ""; settings.defaultCardOrder = nil; settings.defaultHiddenCards = nil
            for key in MobileUISettings.TextKey.allCases { #expect(settings.string(key) == key.builtIn) }
            settings.text = [:]
            #expect(settings == .builtIn)
        }
    }

    // MARK: - 받기·캐시·적용

    private final class FakeFetcher: MobileUIConfigFetching, @unchecked Sendable {
        var response: Result<MobileUIConfigFetchResult, Error> = .failure(URLError(.notConnectedToInternet))
        private(set) var requests: [(url: URL, etag: String?)] = []
        func fetch(_ url: URL, etag: String?) async throws -> MobileUIConfigFetchResult {
            requests.append((url, etag))
            return try response.get()
        }
    }

    private final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 1_800_000_000) }

    private func makeStore(_ fetcher: FakeFetcher, clock: Clock, directory: URL? = nil, defaults: UserDefaults? = nil)
        -> (store: MobileUIConfigStore, directory: URL, defaults: UserDefaults) {
        let directory = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent("daylog-config-\(UUID().uuidString)")
        let defaults = defaults ?? testDefaults()
        let endpoint = URL(string: "https://example.invalid/mobile-ui.json") ?? URL(fileURLWithPath: "/")
        let store = MobileUIConfigStore(
            endpoint: endpoint, fetcher: fetcher, directory: directory, defaults: defaults, appBuild: 5, now: { clock.now }
        )
        return (store, directory, defaults)
    }

    @Test func firstConfigAppliesImmediatelyThenLaterOnesWaitForTheNextActivation() async {
        let fetcher = FakeFetcher(), clock = Clock()
        let (store, _, _) = makeStore(fetcher, clock: clock)
        #expect(store.settings == .builtIn)
        // 처음 받는 설정은 바로 쓴다.
        fetcher.response = .success(.data(json(), etag: "\"a\""))
        await store.activate()
        #expect(store.settings.configVersion == 2 && store.pending == nil)
        #expect(store.lastOutcome == .updated(version: 2, applied: true))
        // 한 시간 안에는 다시 묻지 않는다.
        await store.activate()
        #expect(fetcher.requests.count == 1)
        // 한 시간 뒤: 새 설정은 받아 두기만 한다(쓰는 도중에 화면이 바뀌지 않게).
        clock.now += MobileUIConfigStore.minimumInterval + 1
        fetcher.response = .success(.data(json(["configVersion": 3, "content": ["dashboard": ["greeting": "새 인사"]]]), etag: "\"b\""))
        await store.activate()
        #expect(fetcher.requests.last?.etag == "\"a\"")
        #expect(store.settings.configVersion == 2 && store.pending?.configVersion == 3)
        #expect(store.lastOutcome == .updated(version: 3, applied: false))
        // 다음에 앱으로 돌아오면 적용된다.
        await store.activate()
        #expect(store.settings.configVersion == 3 && store.pending == nil)
        #expect(store.settings.string(.dashboardGreeting) == "새 인사")
    }

    @Test func manualRefreshIgnoresTheIntervalAndAppliesAtOnce() async {
        let fetcher = FakeFetcher(), clock = Clock()
        let (store, _, _) = makeStore(fetcher, clock: clock)
        fetcher.response = .success(.data(json(), etag: "\"a\""))
        await store.activate()
        fetcher.response = .success(.data(json(["configVersion": 3]), etag: "\"b\""))
        await store.refreshNow()
        #expect(fetcher.requests.count == 2)
        #expect(store.settings.configVersion == 3 && store.pending == nil)
        // 바뀐 것이 없으면(304) 그대로다.
        fetcher.response = .success(.notModified)
        await store.refreshNow()
        #expect(store.lastOutcome == .upToDate && store.settings.configVersion == 3)
        #expect(fetcher.requests.last?.etag == "\"b\"")
    }

    @Test func lastValidConfigSurvivesRelaunchOfflineAndBadPublishes() async {
        let fetcher = FakeFetcher(), clock = Clock()
        let (store, directory, defaults) = makeStore(fetcher, clock: clock)
        fetcher.response = .success(.data(json(), etag: "\"a\""))
        await store.refreshNow()
        #expect(store.settings.configVersion == 2)

        // 잘못된 JSON, 모르는 형식, 더 새 앱용 설정: 모두 거부하고 쓰던 설정을 둔다.
        for bad in [Data("{oops".utf8), json(["schemaVersion": 2, "configVersion": 9]), json(["minimumSupportedAppBuild": 99, "configVersion": 9])] {
            fetcher.response = .success(.data(bad, etag: "\"bad\""))
            await store.refreshNow()
            #expect(store.settings.configVersion == 2)
            if case .rejected = store.lastOutcome {} else { Issue.record("거부되지 않았다: \(String(describing: store.lastOutcome))") }
        }
        // 거부한 파일의 ETag는 기억하지 않는다(다음에 다시 받아 본다).
        fetcher.response = .success(.notModified)
        await store.refreshNow()
        #expect(fetcher.requests.last?.etag == "\"a\"")
        // 너무 큰 파일도 거부로 남는다.
        fetcher.response = .failure(MobileUIConfigFetchError.tooLarge)
        await store.refreshNow()
        if case .rejected = store.lastOutcome {} else { Issue.record("크기 초과가 거부로 남지 않았다") }

        // 오프라인: 실패로 남고 쓰던 설정을 둔다.
        fetcher.response = .failure(URLError(.notConnectedToInternet))
        await store.refreshNow()
        #expect(store.lastOutcome == .failed && store.settings.configVersion == 2)

        // 앱을 다시 켜면 저장해 둔 마지막 유효 설정으로 시작한다(네트워크 없이).
        let (relaunched, _, _) = makeStore(FakeFetcher(), clock: clock, directory: directory, defaults: defaults)
        #expect(relaunched.settings.configVersion == 2 && relaunched.settings.accent == .blue)
    }

    @Test func rollbackIsJustAnotherPublishWithOlderContent() async {
        let fetcher = FakeFetcher(), clock = Clock()
        let (store, _, _) = makeStore(fetcher, clock: clock)
        fetcher.response = .success(.data(json(), etag: "\"a\""))
        await store.refreshNow()
        #expect(store.settings.cardStyle == .soft)
        // 이전 내용(기본값)을 새 번호로 다시 게시한 것.
        let rolledBack = json(["configVersion": 3], remove: ["dashboard", "appearance", "content", "features"])
        fetcher.response = .success(.data(rolledBack, etag: "\"c\""))
        await store.refreshNow()
        #expect(store.settings.configVersion == 3)
        #expect(store.settings.cardStyle == .bordered && store.settings.accent == .mint)
        #expect(store.settings.string(.dashboardGreeting) == MobileUISettings.TextKey.dashboardGreeting.builtIn)
    }

    @Test func cacheFromAnotherAddressIsIgnored() async throws {
        let fetcher = FakeFetcher(), clock = Clock()
        let (store, directory, _) = makeStore(fetcher, clock: clock)
        fetcher.response = .success(.data(json(), etag: "\"a\""))
        await store.refreshNow()
        let other = try #require(URL(string: "https://example.invalid/other.json"))
        #expect(MobileUIConfigCache.load(directory: directory, endpoint: other, appBuild: 5) == .builtIn)
        // 지금 앱이 읽을 수 없는 저장본(더 새 앱용)도 쓰지 않는다.
        let endpoint = try #require(URL(string: "https://example.invalid/mobile-ui.json"))
        #expect(MobileUIConfigCache.load(directory: directory, endpoint: endpoint, appBuild: 3) == .builtIn)
        #expect(MobileUIConfigCache.load(directory: directory, endpoint: endpoint, appBuild: 5).configVersion == 2)
    }

    @Test func statusTextsDoNotPromiseAppUpdates() {
        #expect(MobileUIConfigStore.versionText(.builtIn) == "앱 기본값")
        var settings = MobileUISettings(); settings.configVersion = 7
        #expect(MobileUIConfigStore.versionText(settings) == "버전 7")
        #expect(MobileUIConfigStore.outcomeText(.updated(version: 3, applied: false)).contains("다음에 앱을 열 때"))
        #expect(MobileUIConfigStore.outcomeText(.failed).contains("그대로"))
        #expect(MobileUIConfigStore.outcomeText(.rejected("이유.")).contains("그대로"))
    }

    // MARK: - 사용자 배치 우선

    @Test func remoteLayoutDefaultsApplyOnlyUntilTheUserCustomizes() {
        let defaults = testDefaults()
        let preferences = DevicePreferences(defaults: defaults, isPhone: true)
        #expect(!preferences.isLayoutCustomized)
        let remoteOrder = ["summary", "routines", "achievement"]
        preferences.applyRemoteDefaults(order: remoteOrder, hidden: ["calendar"])
        #expect(preferences.cardOrder.prefix(3).map(\.rawValue) == remoteOrder)
        #expect(preferences.hiddenCards == [.calendar])
        #expect(!preferences.isLayoutCustomized)

        // 사용자가 카드를 숨기면 그때부터는 사용자의 배치다.
        preferences.setVisible(false, card: .meals)
        #expect(preferences.isLayoutCustomized)
        let order = preferences.cardOrder, hidden = preferences.hiddenCards
        preferences.applyRemoteDefaults(order: ["trend", "routines"], hidden: ["summary"])
        #expect(preferences.cardOrder == order && preferences.hiddenCards == hidden)
        // 다시 켜도(저장된 값으로) 그대로다.
        let relaunched = DevicePreferences(defaults: defaults, isPhone: true)
        #expect(relaunched.isLayoutCustomized && relaunched.hiddenCards == hidden)

        // [기본 배치 복원]은 지금의 기본값(원격이 준 것)으로 돌아가고, 다시 기본값을 따른다.
        preferences.restoreDashboard()
        #expect(!preferences.isLayoutCustomized)
        #expect(preferences.cardOrder.first == .trend && preferences.hiddenCards == [.summary])
    }

    @Test func layoutsSavedBeforeThisFeatureCountAsCustomizedOnlyIfTheyDifferFromTheDefault() {
        // 예전 버전이 저장한 기본 배치 그대로: 사용자가 바꾼 것이 아니다.
        let untouched = testDefaults()
        untouched.set(DashboardCard.defaultOrder(phone: true).map(\.rawValue), forKey: DevicePreferences.orderKey)
        untouched.set(DashboardCard.defaultHidden.map(\.rawValue), forKey: DevicePreferences.hiddenKey)
        untouched.set(DashboardCard.defaultLeft.map(\.rawValue), forKey: DevicePreferences.leftKey)
        untouched.set(DevicePreferences.layoutVersion, forKey: DevicePreferences.layoutVersionKey)
        #expect(!DevicePreferences(defaults: untouched, isPhone: true).isLayoutCustomized)

        // 예전 버전에서 카드를 하나 더 숨겨 둔 사용자: 그 배치를 지킨다.
        let changed = testDefaults()
        changed.set(DashboardCard.defaultOrder(phone: true).map(\.rawValue), forKey: DevicePreferences.orderKey)
        changed.set((DashboardCard.defaultHidden.map(\.rawValue) + ["meals"]), forKey: DevicePreferences.hiddenKey)
        changed.set(DashboardCard.defaultLeft.map(\.rawValue), forKey: DevicePreferences.leftKey)
        changed.set(DevicePreferences.layoutVersion, forKey: DevicePreferences.layoutVersionKey)
        let preferences = DevicePreferences(defaults: changed, isPhone: true)
        #expect(preferences.isLayoutCustomized)
        preferences.applyRemoteDefaults(order: ["summary", "routines"], hidden: [])
        #expect(preferences.hiddenCards.contains(.meals))
    }

    @Test func remoteOrderIsForThePhoneLayoutOnlyAndNeverTouchesPersonalSettings() {
        let defaults = testDefaults()
        let pad = DevicePreferences(defaults: defaults, isPhone: false)
        pad.setMealsEnabled(false)
        pad.applyRemoteDefaults(order: ["trend", "routines"], hidden: ["summary"])
        // iPad·Mac의 두 열 순서는 내장 순서를 따른다. 숨김 기본값만 받는다.
        #expect(pad.cardOrder == DashboardCard.defaultOrder(phone: false))
        #expect(pad.hiddenCards == [.summary])
        // 식사 표시 같은 개인 설정은 원격 설정이 바꾸지 못한다.
        #expect(!pad.mealsEnabled)
    }
}
