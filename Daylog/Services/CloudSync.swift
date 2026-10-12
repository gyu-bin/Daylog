import CloudKit
import CoreData
import Foundation
import Observation
#if os(macOS)
import Security
#endif

/// iCloud 동기화를 켤지 여부. 앱 서명에 들어 있는 권한만 보고 정한다.
///
/// 컨테이너 이름을 코드에 적어 두지 않는다. Xcode의 Signing & Capabilities에서 iCloud(CloudKit)를
/// 켜면 서명에 컨테이너가 들어가고, 그때부터 동기화가 켜진다. 권한이 없는 빌드는 지금까지처럼 로컬 전용이다.
enum CloudSyncConfiguration {
    #if os(macOS)
    static var containerIdentifier: String? {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        func entitlement(_ key: String) -> [String] {
            SecTaskCopyValueForEntitlement(task, key as CFString, nil) as? [String] ?? []
        }
        guard entitlement("com.apple.developer.icloud-services").contains("CloudKit") else { return nil }
        return entitlement("com.apple.developer.icloud-container-identifiers").first
    }

    /// 이 빌드가 쓰는 CloudKit 환경. Developer ID로 배포한 앱은 "Production", Xcode로 직접 빌드한 앱은 "Development".
    /// 두 환경의 기록은 같은 계정이어도 서로 따로다.
    static var environment: String? {
        guard containerIdentifier != nil, let task = SecTaskCreateFromSelf(nil) else { return nil }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-environment" as CFString, nil)
        // 개발용 서명에는 이 권한이 없고, 그때 CloudKit은 Development를 쓴다.
        return (value as? String) ?? "Development"
    }
    #else
    /// iOS·iPadOS 앱은 Mac 앱과 같은 컨테이너를 쓴다(번들 ID가 달라 이름을 직접 적는다. 권한 파일의 값과 같아야 한다).
    /// 시뮬레이터에서는 iCloud에 연결하지 않고 그 기기에만 저장한다.
    static var containerIdentifier: String? {
        #if targetEnvironment(simulator)
        return nil
        #else
        return "iCloud.com.mungyubin.daylog"
        #endif
    }

    /// Xcode로 기기에 직접 설치한 앱은 "Development", TestFlight·App Store로 설치한 앱은 "Production".
    /// iOS에는 자기 권한을 읽는 API가 없어서, 개발용 설치에만 들어 있는 프로비저닝 프로파일로 가린다.
    static var environment: String? {
        guard containerIdentifier != nil else { return nil }
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1)
        else { return "Production" }
        // 프로파일 안의 aps-environment가 development면 개발용 설치다.
        let isDevelopment = text.range(
            of: "<key>aps-environment</key>\\s*<string>development</string>", options: .regularExpression
        ) != nil
        return isDevelopment ? "Development" : "Production"
    }
    #endif
}

/// 설정 화면에 보여 줄 iCloud 상태. 시스템이 공식적으로 알려 주는 것만 담는다.
///
/// 여기의 시각은 "이 Mac이 마지막으로 변경을 가져오거나 보낸 시각"이지, 모든 기록이 다른 기기에
/// 반영됐다는 뜻이 아니다. CloudKit은 그걸 알려 주지 않는다.
@MainActor
@Observable
final class CloudSyncMonitor {
    enum Account: Equatable {
        case notConfigured
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case unknown(String)

        var title: String {
            switch self {
            case .notConfigured: return "사용 안 함 (이 빌드에는 iCloud 권한이 없어요)"
            case .checking: return "확인 중…"
            case .available: return "iCloud 연결됨"
            case .noAccount: return "iCloud에 로그인되어 있지 않아요"
            case .restricted: return "\(Platform.thisDevice)에서는 iCloud 사용이 제한되어 있어요"
            case .temporarilyUnavailable: return "iCloud를 일시적으로 사용할 수 없어요"
            case .unknown(let detail): return "iCloud 상태를 확인하지 못했어요 (\(detail))"
            }
        }
    }

    let containerIdentifier: String?
    /// 이 앱이 쓰는 CloudKit 환경("Development"/"Production"). 두 Mac의 환경이 같아야 서로 동기화된다.
    let environment: String?
    private(set) var account: Account
    private(set) var lastImportAt: Date?
    private(set) var lastExportAt: Date?
    private(set) var lastErrorMessage: String?
    private(set) var checkedAt: Date?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    var isEnabled: Bool { containerIdentifier != nil }

    /// iCloud를 쓰는데 이번 실행에서 아직 한 번도 가져오기를 마치지 않았다.
    /// 이때 화면이 비어 있으면 "기록이 없다"가 아니라 "아직 받는 중일 수 있다"로 안내한다.
    var isWaitingForFirstImport: Bool {
        guard isEnabled, lastImportAt == nil else { return false }
        return account == .checking || account == .available
    }

    /// 설정 화면에 보여 줄 환경 이름.
    var environmentTitle: String? {
        switch environment {
        case "Production"?: return "Production (배포판)"
        case "Development"?: return "Development (개발용 설치)"
        default: return environment
        }
    }

    init(containerIdentifier: String?, environment: String? = nil) {
        self.containerIdentifier = containerIdentifier
        self.environment = environment
        self.account = containerIdentifier == nil ? .notConfigured : .checking
    }

    func start() {
        guard isEnabled, observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
            guard let event, let endDate = event.endDate else { return }
            let type = event.type
            let failure = event.succeeded ? nil : (event.error?.localizedDescription ?? "알 수 없는 오류")
            MainActor.assumeIsolated {
                self?.record(type: type, endDate: endDate, failure: failure)
            }
        })
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAccountStatus()
            }
        })
        refreshAccountStatus()
    }

    /// 계정 상태를 다시 확인한다. 동기화를 강제로 실행하지는 않는다(그런 공식 API가 없다).
    func refreshAccountStatus() {
        guard let containerIdentifier else { return }
        Task {
            do {
                let status = try await CKContainer(identifier: containerIdentifier).accountStatus()
                switch status {
                case .available: account = .available
                case .noAccount: account = .noAccount
                case .restricted: account = .restricted
                case .temporarilyUnavailable: account = .temporarilyUnavailable
                case .couldNotDetermine: account = .unknown("확인 불가")
                @unknown default: account = .unknown("알 수 없는 상태")
                }
            } catch {
                account = .unknown(error.localizedDescription)
            }
            checkedAt = .now
        }
    }

    private func record(type: NSPersistentCloudKitContainer.EventType, endDate: Date, failure: String?) {
        if let failure {
            lastErrorMessage = failure
            return
        }
        switch type {
        case .import: lastImportAt = endDate
        case .export: lastExportAt = endDate
        case .setup: break
        @unknown default: break
        }
        lastErrorMessage = nil
    }
}

/// 설정 맨 위에 보여 줄 동기화 요약: 한 낱말의 상태와 한 줄 설명. 시스템이 알려 준 값에서 계산만 한다.
struct SyncSummary: Equatable {
    enum Tone: Equatable {
        case good, waiting, warning, off
    }

    var title: String
    var detail: String
    var tone: Tone

    static func make(
        isEnabled: Bool, account: CloudSyncMonitor.Account, lastImportAt: Date?, lastExportAt: Date?,
        errorMessage: String?, now: Date
    ) -> SyncSummary {
        guard isEnabled else {
            return SyncSummary(title: "사용 안 함", detail: "기록을 이 기기에만 저장해요", tone: .off)
        }
        switch account {
        case .available: break
        case .checking: return SyncSummary(title: "확인 중", detail: "iCloud 계정을 확인하고 있어요", tone: .waiting)
        default: return SyncSummary(title: "연결 안 됨", detail: account.title, tone: .warning)
        }
        if errorMessage != nil {
            return SyncSummary(title: "오류", detail: "최근 동기화에 실패했어요", tone: .warning)
        }
        guard let last = [lastImportAt, lastExportAt].compactMap({ $0 }).max() else {
            return SyncSummary(title: "대기 중", detail: "아직 주고받은 변경이 없어요", tone: .waiting)
        }
        return SyncSummary(title: "정상", detail: "마지막 동기화 \(relative(last, now: now))", tone: .good)
    }

    /// "방금 전", "5분 전", "3시간 전", "2일 전".
    static func relative(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "방금 전" }
        if seconds < 3600 { return "\(seconds / 60)분 전" }
        if seconds < 86400 { return "\(seconds / 3600)시간 전" }
        return "\(seconds / 86400)일 전"
    }
}
