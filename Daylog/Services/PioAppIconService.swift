import Foundation
#if os(iOS)
import UIKit
#endif

/// An outfit entitlement does not imply that alternate-icon files were shipped.
@MainActor
enum PioAppIconService {
    /// 의상별 대체 아이콘(2026-10-25). 이름은 Assets.xcassets의 `AppIcon-<의상>.appiconset`이고,
    /// iOS 타깃의 ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES에 같은 이름이 있어야 Info.plist(CFBundleAlternateIcons)에 들어간다.
    static let registeredThemes: [PioOutfitID: String] = Dictionary(uniqueKeysWithValues:
        PioOutfitID.allCases.filter { $0 != .basic }.map { ($0, "AppIcon-\($0.rawValue)") })
    /// 의상 전용 아이콘이 하나라도 앱에 들어 있을 때만 옷장의 '앱 아이콘' 탭을 보인다.
    static var hasShippedThemes: Bool { !registeredThemes.isEmpty }

    static func isAvailable(_ outfit: PioOutfitID, info: [String: Any] = Bundle.main.infoDictionary ?? [:]) -> Bool {
        #if os(iOS)
        if outfit == .basic { return true }
        guard let name = registeredThemes[outfit],
              let icons = info["CFBundleIcons"] as? [String: Any],
              let alternates = icons["CFBundleAlternateIcons"] as? [String: Any],
              alternates[name] != nil else { return false }
        return true
        #else
        return false
        #endif
    }

    static func canSelect(_ outfit: PioOutfitID, store: PioWardrobeStore) -> Bool {
        guard store.owns(outfit), isAvailable(outfit) else { return false }
        #if os(iOS)
        return UIApplication.shared.supportsAlternateIcons
        #else
        return false
        #endif
    }

    /// 성공하면 nil(아이콘이 바뀌면 iOS가 직접 "아이콘을 변경했습니다" 창을 띄우므로 앱은 따로 알리지 않는다). 실패 까닭만 돌려준다.
    static func select(_ outfit: PioOutfitID, store: PioWardrobeStore) async -> String? {
        guard store.owns(outfit) else { return "보유한 의상의 아이콘만 선택할 수 있어요." }
        guard canSelect(outfit, store: store) else { return "이 아이콘은 아직 앱에 준비되어 있지 않아요." }
        #if os(iOS)
        do {
            if UIApplication.shared.alternateIconName != registeredThemes[outfit] {
                try await UIApplication.shared.setAlternateIconName(registeredThemes[outfit])
            }
            guard store.selectIcon(outfit) else {
                // Ownership may have been revoked while the system was changing the icon.
                try? await UIApplication.shared.setAlternateIconName(nil)
                return "구매 내역을 다시 확인해 주세요. 기본 아이콘으로 돌아갔어요."
            }
            return nil
        } catch { return "앱 아이콘을 변경하지 못했어요. 잠시 후 다시 시도해 주세요." }
        #else
        return "현재 Mac에서는 앱 아이콘 변경을 지원하지 않아요."
        #endif
    }
}

extension PioAppIconService {
    /// 홈 화면 아이콘과 구매 내역을 맞춘다. 구매 내역이 검증된 뒤에만 움직인다(오프라인·조회 실패 때는 그대로 둔다).
    /// - 지금 아이콘이 소유하지 않은 의상(환불·다른 계정)이면 기본 아이콘으로 되돌린다.
    /// - 지금 아이콘이 소유한 의상이면 옷장의 선택 표시를 그 아이콘에 맞춘다(재설치 뒤 등).
    /// 시스템 아이콘을 새로 바꾸는 일은 사용자가 고를 때만 한다(바꿀 때마다 iOS가 안내 창을 띄운다).
    static func reconcile(store: PioWardrobeStore) async {
        #if os(iOS)
        guard store.purchases.entitlementState == .verified,
              let current = UIApplication.shared.alternateIconName else { return }
        guard let outfit = registeredThemes.first(where: { $0.value == current })?.key, store.owns(outfit) else {
            try? await UIApplication.shared.setAlternateIconName(nil)
            store.selectIcon(.basic)
            return
        }
        if store.selectedIcon != outfit { store.selectIcon(outfit) }
        #endif
    }
}

extension PioWardrobeEntitlementResult {
    var wardrobeMessage: String? {
        switch self {
        case .purchased: return "구매가 완료됐어요. 이제 피오에게 입혀 주세요."
        case .restored(let outfits):
            return outfits.isEmpty ? "복원할 의상 구매 내역이 없어요." : "의상 \(outfits.count)개의 구매 내역을 복원했어요."
        case .cancelled: return nil
        case .pending: return "구매 승인을 기다리고 있어요. 승인되면 옷장에 자동으로 추가돼요."
        case .unverified: return "구매를 안전하게 확인하지 못했어요. 의상은 아직 잠겨 있어요. 구매 복원을 다시 시도해 주세요."
        case .unavailable(let message), .failed(let message): return message
        }
    }
}
