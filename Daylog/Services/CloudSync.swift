import CloudKit
import CoreData
import Foundation
import Observation
import Security

/// iCloud 동기화를 켤지 여부. 앱 서명에 들어 있는 권한만 보고 정한다.
///
/// 컨테이너 이름을 코드에 적어 두지 않는다. Xcode의 Signing & Capabilities에서 iCloud(CloudKit)를
/// 켜면 서명에 컨테이너가 들어가고, 그때부터 동기화가 켜진다. 권한이 없는 빌드는 지금까지처럼 로컬 전용이다.
enum CloudSyncConfiguration {
    static var containerIdentifier: String? {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        func entitlement(_ key: String) -> [String] {
            SecTaskCopyValueForEntitlement(task, key as CFString, nil) as? [String] ?? []
        }
        guard entitlement("com.apple.developer.icloud-services").contains("CloudKit") else { return nil }
        return entitlement("com.apple.developer.icloud-container-identifiers").first
    }
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
            case .restricted: return "이 Mac에서는 iCloud 사용이 제한되어 있어요"
            case .temporarilyUnavailable: return "iCloud를 일시적으로 사용할 수 없어요"
            case .unknown(let detail): return "iCloud 상태를 확인하지 못했어요 (\(detail))"
            }
        }
    }

    let containerIdentifier: String?
    private(set) var account: Account
    private(set) var lastImportAt: Date?
    private(set) var lastExportAt: Date?
    private(set) var lastErrorMessage: String?
    private(set) var checkedAt: Date?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    var isEnabled: Bool { containerIdentifier != nil }

    init(containerIdentifier: String?) {
        self.containerIdentifier = containerIdentifier
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
