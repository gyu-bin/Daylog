import Foundation
import Observation

/// 설정 파일을 받아 오는 일. 테스트에서는 가짜로 바꾼다.
protocol MobileUIConfigFetching: Sendable {
    /// `etag`가 있으면 조건부로 요청한다. 바뀌지 않았으면 `.notModified`.
    func fetch(_ url: URL, etag: String?) async throws -> MobileUIConfigFetchResult
}

enum MobileUIConfigFetchResult: Equatable, Sendable {
    case notModified
    case data(Data, etag: String?)
}

enum MobileUIConfigFetchError: Error, Equatable {
    case insecureURL
    case status(Int)
    case tooLarge
}

/// 설정을 받는 주소. 앱에 고정돼 있고 원격 설정이나 사용자 설정으로 바꿀 수 없다.
enum MobileUIConfigChannel {
    /// 배포판(TestFlight·App Store)이 보는 주소. `Tools/mobile-config.sh publish`가 이 파일을 바꾼다.
    static let production = "https://github.com/gyu-bin/Daylog/releases/download/mobile-config/mobile-ui.json"
    /// Debug 빌드가 보는 주소. 배포판 사용자에게는 영향이 없다.
    static let development = "https://github.com/gyu-bin/Daylog/releases/download/mobile-config-dev/mobile-ui.json"

    static var current: URL {
        #if DEBUG
        // 이 Mac의 시험 서버로 바꿔 볼 수 있다(Debug 빌드 전용, 127.0.0.1만).
        if let override = UserDefaults.standard.string(forKey: "DaylogDebugConfigURL"),
           let url = URL(string: override), isAllowed(url) {
            return url
        }
        return URL(string: development) ?? URL(fileURLWithPath: "/")
        #else
        return URL(string: production) ?? URL(fileURLWithPath: "/")
        #endif
    }

    /// HTTPS만 받는다. Debug 빌드에서만 이 Mac의 시험 서버(http://127.0.0.1)를 더 허용한다.
    static func isAllowed(_ url: URL) -> Bool {
        if url.scheme == "https", url.host != nil, url.user == nil, url.password == nil { return true }
        #if DEBUG
        if url.scheme == "http", url.host == "127.0.0.1" { return true }
        #endif
        return false
    }
}

/// 디스크에 남겨 둔 마지막 유효 설정. 앱을 켤 때와 오프라인일 때 이것을 쓴다.
enum MobileUIConfigCache {
    static let fileName = "mobile-ui.json"
    static let sourceFileName = "mobile-ui.source"

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("MobileConfig", isDirectory: true)
    }

    static var appBuild: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
    }

    /// 저장해 둔 설정을 읽는다. 없거나, 다른 주소에서 받은 것이거나, 지금 앱이 읽을 수 없으면 내장 기본값.
    static func load(directory: URL, endpoint: URL, appBuild: Int) -> MobileUISettings {
        let source = try? String(contentsOf: directory.appendingPathComponent(sourceFileName), encoding: .utf8)
        guard source == endpoint.absoluteString,
              let data = try? Data(contentsOf: directory.appendingPathComponent(fileName)),
              let config = try? MobileUIConfig.decode(data, appBuild: appBuild)
        else { return .builtIn }
        return config.resolved()
    }

    static func save(_ data: Data, directory: URL, endpoint: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        try Data(endpoint.absoluteString.utf8).write(to: directory.appendingPathComponent(sourceFileName), options: .atomic)
    }

    /// 앱이 켜질 때의 설정. 강조 색처럼 실행 중에 바꾸지 않는 값이 이것을 읽는다.
    static let atLaunch: MobileUISettings = {
        #if os(iOS)
        load(directory: defaultDirectory, endpoint: MobileUIConfigChannel.current, appBuild: appBuild)
        #else
        .builtIn
        #endif
    }()
}

/// 원격 UI 설정의 상태와 갱신. iPhone·iPad에서만 만든다.
///
/// - 화면이 쓰는 값은 `settings` 하나다. 내장 기본값 → 저장해 둔 마지막 유효 설정 → 새로 받은 설정 순으로 바뀐다.
/// - 스스로 확인해 받은 설정은 바로 적용하지 않고 `pending`에 두었다가, 다음에 앱을 열거나 돌아올 때 적용한다
///   (쓰는 도중에 화면이 움직이지 않게). 사용자가 [UI 설정 새로고침]을 누른 경우에는 바로 적용한다.
///   설정을 한 번도 받은 적 없는 설치의 첫 설정도 바로 적용한다(새 사용자가 처음부터 그 기본값으로 시작하게).
/// - 받지 못했거나 검사에서 떨어진 설정은 쓰지 않고, 지금 쓰던 설정을 그대로 둔다.
@MainActor
@Observable
final class MobileUIConfigStore {
    enum Outcome: Equatable {
        /// 바뀐 것이 없다.
        case upToDate
        /// 새 설정을 받았다. `applied`가 false면 다음에 앱을 열 때 적용된다.
        case updated(version: Int, applied: Bool)
        /// 받았지만 쓸 수 없는 설정이었다.
        case rejected(String)
        /// 받지 못했다(오프라인 등).
        case failed
    }

    static let etagKey = "mobileUIConfig.etag"
    static let lastCheckedKey = "mobileUIConfig.lastCheckedAt"
    /// 스스로 확인하는 최소 간격.
    static let minimumInterval: TimeInterval = 60 * 60

    private(set) var settings: MobileUISettings
    private(set) var pending: MobileUISettings?
    private(set) var lastCheckedAt: Date?
    private(set) var lastOutcome: Outcome?
    private(set) var isRefreshing = false

    @ObservationIgnored private let endpoint: URL
    @ObservationIgnored private let fetcher: MobileUIConfigFetching
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let appBuild: Int
    @ObservationIgnored private let now: () -> Date

    #if os(iOS)
    /// 앱이 쓰는 하나뿐인 저장소(iPhone·iPad).
    static let shared = MobileUIConfigStore()
    #endif

    init(
        endpoint: URL = MobileUIConfigChannel.current,
        fetcher: MobileUIConfigFetching = URLSessionMobileUIConfigFetcher(),
        directory: URL = MobileUIConfigCache.defaultDirectory,
        defaults: UserDefaults = .standard,
        appBuild: Int = MobileUIConfigCache.appBuild,
        now: @escaping () -> Date = { Date() }
    ) {
        self.endpoint = endpoint
        self.fetcher = fetcher
        self.directory = directory
        self.defaults = defaults
        self.appBuild = appBuild
        self.now = now
        settings = MobileUIConfigCache.load(directory: directory, endpoint: endpoint, appBuild: appBuild)
        lastCheckedAt = defaults.object(forKey: Self.lastCheckedKey) as? Date
    }

    /// 앱을 열었거나 다시 돌아왔을 때. 받아 둔 설정이 있으면 적용하고, 확인한 지 오래됐으면 새로 확인한다.
    func activate() async {
        if let pending {
            settings = pending
            self.pending = nil
        }
        if let lastCheckedAt, now().timeIntervalSince(lastCheckedAt) < Self.minimumInterval { return }
        await check(appliesImmediately: false)
    }

    /// 사용자가 [UI 설정 새로고침]을 눌렀을 때. 간격과 상관없이 확인하고, 받은 설정은 바로 적용한다.
    func refreshNow() async {
        await check(appliesImmediately: true)
        if let pending {
            settings = pending
            self.pending = nil
            if case .updated(let version, _) = lastOutcome { lastOutcome = .updated(version: version, applied: true) }
        }
    }

    private func check(appliesImmediately: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        // 저장해 둔 설정이 없으면(지워졌거나 주소가 바뀌었으면) 조건 없이 다시 받는다.
        let hasCache = FileManager.default.fileExists(atPath: directory.appendingPathComponent(MobileUIConfigCache.fileName).path)
        let etag = hasCache ? defaults.string(forKey: Self.etagKey) : nil
        // 처음 받는 설정은 기다리게 하지 않는다.
        let appliesImmediately = appliesImmediately || !hasCache
        do {
            let result = try await fetcher.fetch(endpoint, etag: etag)
            markChecked()
            switch result {
            case .notModified:
                lastOutcome = .upToDate
            case .data(let data, let newETag):
                let config = try MobileUIConfig.decode(data, appBuild: appBuild)
                let resolved = config.resolved()
                try MobileUIConfigCache.save(data, directory: directory, endpoint: endpoint)
                defaults.set(newETag, forKey: Self.etagKey)
                if resolved == settings || resolved == pending {
                    lastOutcome = .upToDate
                } else if appliesImmediately {
                    settings = resolved
                    pending = nil
                    lastOutcome = .updated(version: resolved.configVersion, applied: true)
                } else {
                    pending = resolved
                    lastOutcome = .updated(version: resolved.configVersion, applied: false)
                }
            }
        } catch let error as MobileUIConfigError {
            // 쓸 수 없는 설정: 지금 쓰던 것을 그대로 둔다. 다음 확인 때 다시 받아 본다(ETag를 남기지 않는다).
            markChecked()
            lastOutcome = .rejected(error.message)
        } catch MobileUIConfigFetchError.tooLarge {
            // 받다가 크기 한도를 넘었다: 쓸 수 없는 설정이다.
            markChecked()
            lastOutcome = .rejected(MobileUIConfigError.tooLarge(MobileUIConfig.maximumSize).message)
        } catch {
            lastOutcome = .failed
        }
    }

    #if DEBUG
    /// 화면 검증용: 마지막 확인 시각을 잊어, 다음 `activate()`가 간격과 상관없이 확인하게 한다.
    func forgetLastCheckForTesting() {
        lastCheckedAt = nil
        defaults.removeObject(forKey: Self.lastCheckedKey)
    }
    #endif

    /// 설정 화면에 보여 주는 지금의 설정 버전.
    var versionText: String { Self.versionText(settings) }

    static func versionText(_ settings: MobileUISettings) -> String {
        settings.configVersion == 0 ? "앱 기본값" : "버전 \(settings.configVersion)"
    }

    /// 설정 화면에 보여 주는 마지막 확인 결과 한 줄. 아직 확인한 적 없으면 nil.
    var outcomeText: String? { lastOutcome.map(Self.outcomeText) }

    static func outcomeText(_ outcome: Outcome) -> String {
        switch outcome {
        case .upToDate: return "지금 쓰는 설정이 최신이에요."
        case .updated(let version, true): return "버전 \(version)을 받아 적용했어요."
        case .updated(let version, false): return "버전 \(version)을 받았어요. 다음에 앱을 열 때 적용돼요."
        case .rejected(let reason): return "\(reason) 지금 쓰는 설정을 그대로 둡니다."
        case .failed: return "확인하지 못했어요. 지금 쓰는 설정을 그대로 둡니다."
        }
    }

    /// 받은 설정의 강조 색이 지금 화면의 색과 다르다(앱을 다시 열어야 바뀐다).
    var accentChangesOnRelaunch: Bool { settings.accent != MobileUIConfigCache.atLaunch.accent }

    private func markChecked() {
        let date = now()
        lastCheckedAt = date
        defaults.set(date, forKey: Self.lastCheckedKey)
    }
}

/// 실제 네트워크. 쿠키·캐시를 남기지 않는 세션으로 한 번 요청한다.
struct URLSessionMobileUIConfigFetcher: MobileUIConfigFetching {
    func fetch(_ url: URL, etag: String?) async throws -> MobileUIConfigFetchResult {
        guard MobileUIConfigChannel.isAllowed(url) else { throw MobileUIConfigFetchError.insecureURL }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw MobileUIConfigFetchError.status(0) }
        // 다른 주소로 넘겨졌어도 마지막 주소가 허용되는 것이어야 한다.
        if let final = http.url, !MobileUIConfigChannel.isAllowed(final) { throw MobileUIConfigFetchError.insecureURL }
        if http.statusCode == 304 { return .notModified }
        guard http.statusCode == 200 else { throw MobileUIConfigFetchError.status(http.statusCode) }
        if http.expectedContentLength > Int64(MobileUIConfig.maximumSize) { throw MobileUIConfigFetchError.tooLarge }
        // 크기 한도를 넘으면 끝까지 받지 않고 그만둔다.
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > MobileUIConfig.maximumSize { throw MobileUIConfigFetchError.tooLarge }
        }
        return .data(data, etag: http.value(forHTTPHeaderField: "ETag"))
    }
}
