import Foundation
#if os(iOS)
import UIKit
#endif

/// An outfit entitlement does not imply that alternate-icon files were shipped.
@MainActor
enum PioAppIconService {
    // Populate only after the matching icon sets and Info.plist entries exist.
    static let registeredThemes: [PioOutfitID: String] = [:]

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

    static func select(_ outfit: PioOutfitID, store: PioWardrobeStore) async -> String {
        guard store.owns(outfit) else { return "보유한 의상의 아이콘만 선택할 수 있어요." }
        guard canSelect(outfit, store: store) else { return "이 아이콘은 아직 앱에 준비되어 있지 않아요." }
        #if os(iOS)
        do {
            try await UIApplication.shared.setAlternateIconName(registeredThemes[outfit])
            guard store.selectIcon(outfit) else {
                // Ownership may have been revoked while the system was changing the icon.
                try? await UIApplication.shared.setAlternateIconName(nil)
                return "구매 내역을 다시 확인해 주세요. 기본 아이콘으로 돌아갔어요."
            }
            return "앱 아이콘을 변경했어요. 착용한 의상은 그대로예요."
        } catch { return "앱 아이콘을 변경하지 못했어요. 잠시 후 다시 시도해 주세요." }
        #else
        return "현재 Mac에서는 앱 아이콘 변경을 지원하지 않아요."
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
