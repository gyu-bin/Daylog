import Foundation

/// 입은 옷을 같은 Apple 계정의 기기끼리 맞춘다(2026-10-26). iCloud 키-값 저장소에 "무엇을 입었는지"만 둔다.
/// 표시 설정일 뿐 구매 영수증이 아니다: 받은 기기에서도 검증된 소유가 있어야 입혀지고, 없으면 소유가 확인될 때까지 기다린다.
/// iPhone·iPad·Mac App Store판은 번들 ID가 같아 같은 저장소를 쓴다. DMG판·시험 모드는 쓰지 않는다.
@MainActor final class PioWardrobeCloudSelection {
    static let key = "pio.equippedOutfit.v1"
    private let store: NSUbiquitousKeyValueStore
    private var observer: NSObjectProtocol?

    init(store: NSUbiquitousKeyValueStore = .default) { self.store = store }

    var remoteOutfit: PioOutfitID? { store.string(forKey: Self.key).flatMap(PioOutfitID.init(rawValue:)) }

    func push(_ outfit: PioOutfitID) {
        guard remoteOutfit != outfit else { return }
        store.set(outfit.rawValue, forKey: Self.key)
        store.synchronize()
    }

    /// 다른 기기에서 바뀌면 알려 준다. 시작할 때 한 번 최신 값을 받아 온다.
    func observe(_ onChange: @escaping @MainActor (PioOutfitID) -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if let outfit = self?.remoteOutfit { onChange(outfit) }
            }
        }
        store.synchronize()
    }

    /// 실제 판매 환경의 앱만 쓴다(테스트·DMG판 제외).
    static func current(for availability: PioPurchaseAvailability, outfitTesting: Bool) -> PioWardrobeCloudSelection? {
        guard !RuntimeEnvironment.isRunningTests, !outfitTesting, availability == .appStore,
              UserDefaults.standard.string(forKey: "DaylogStoreName") == nil else { return nil }
        return PioWardrobeCloudSelection()
    }
}
