import Foundation

/// Only bundled, reviewed configuration may activate the updater (never UserDefaults).
struct UpdateConfiguration: Equatable {
    let enabled: Bool
    let feedURL: String
    let publicKey: String
    /// 이 앱의 번들 ID. 검증 전용 번들인지 가리는 데만 쓴다.
    let bundleID: String

    /// 실제 앱과 분리된 검증 전용 번들. 이 번들에서만 이 Mac의 시험용 피드를 허용한다.
    static let verificationBundleID = "com.daylog.verify"
    /// 업데이트 설치 시험(Tools/update-test.sh)이 쓰는 번들. 서명이 달라 검증 번들과 컨테이너를 나눠 쓴다.
    static let updateTestBundleID = "com.daylog.updatetest"

    init(info: [String: Any], bundleID: String = "") {
        enabled = info["DaylogUpdatesEnabled"] as? Bool ?? false
        feedURL = info["SUFeedURL"] as? String ?? ""
        publicKey = info["SUPublicEDKey"] as? String ?? ""
        self.bundleID = bundleID
    }

    var isReady: Bool {
        guard enabled, let url = URL(string: feedURL), url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil,
              isReleaseFeed(url) || isLocalTestFeed(url),
              let key = Data(base64Encoded: publicKey), key.count == 32,
              key.contains(where: { $0 != 0 }) else { return false }
        return true
    }

    /// 배포판이 쓰는 단 하나의 피드: GitHub의 최신 릴리스에 올린 appcast.
    private func isReleaseFeed(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "github.com"
            && url.path == "/gyu-bin/Daylog/releases/latest/download/appcast.xml"
    }

    /// 업데이트 설치를 실제 앱과 분리해 시험할 때 쓰는 이 Mac의 피드. 검증 전용 번들에서만 받아들인다.
    /// 이때도 Sparkle의 EdDSA 서명 검증은 그대로 거친다.
    private func isLocalTestFeed(_ url: URL) -> Bool {
        [Self.verificationBundleID, Self.updateTestBundleID].contains(bundleID)
            && url.scheme == "http" && url.host == "127.0.0.1" && url.path == "/appcast.xml"
    }
}

/// 마지막 업데이트 확인의 결과. 설정의 앱 정보가 보여 준다. 실제 창(새 버전 안내, 변경 사항, 설치 승인, 오류)은 Sparkle이 띄운다.
enum UpdateCheckOutcome: Equatable {
    case upToDate
    case found(version: String)
    case failed(message: String)

    /// Sparkle 오류 영역과, 실패가 아닌 코드: 새 버전 없음(1001), 사용자가 설치를 취소함(4007).
    static let sparkleErrorDomain = "SUSparkleErrorDomain"
    static let noUpdateCode = 1001
    static let installationCanceledCode = 4007

    /// 확인 한 번이 끝났을 때의 결과. 알릴 것이 없으면(사용자가 취소했거나 건너뜀) nil.
    static func resolve(foundVersion: String?, errorDomain: String?, errorCode: Int?, errorMessage: String?) -> UpdateCheckOutcome? {
        if let errorCode, errorDomain == sparkleErrorDomain {
            if errorCode == noUpdateCode { return .upToDate }
            if errorCode == installationCanceledCode { return foundVersion.map { .found(version: $0) } }
        }
        if errorCode != nil {
            return .failed(message: errorMessage ?? "업데이트를 확인하지 못했어요.")
        }
        return foundVersion.map { .found(version: $0) }
    }

    /// 설정에 보여 주는 한 줄.
    static func statusText(isConfigured: Bool, outcome: UpdateCheckOutcome?, currentVersion: String) -> String {
        guard isConfigured else {
            return "이 버전은 앱 안에서 업데이트를 받을 수 없어요. 새 버전은 GitHub 릴리스에서 받을 수 있어요."
        }
        switch outcome {
        case nil: return "새 버전이 있으면 변경 사항을 보여 주고, 설치를 누르면 내려받아 바꾼 뒤 다시 열어요."
        case .upToDate: return "최신 버전이에요 (\(currentVersion))."
        case .found(let version): return "새 버전 \(version)이 있어요. [업데이트 확인]에서 설치할 수 있어요."
        case .failed(let message): return "확인하지 못했어요: \(message)"
        }
    }

    static let releasesPage = URL(string: "https://github.com/gyu-bin/Daylog/releases/latest")
}
