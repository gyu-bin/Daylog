import Foundation
import Testing
@testable import Daylog

@MainActor
struct PioAppIconTests {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent() }

    /// 유료 의상 13종마다 대체 아이콘이 하나씩 있고, 이름·그림 파일·iOS 빌드 설정이 서로 맞는다(2026-10-25).
    @Test func everyPremiumOutfitShipsAMatchingAlternateIcon() throws {
        let premium = PioOutfitID.allCases.filter { $0 != .basic }
        #expect(PioAppIconService.registeredThemes.count == premium.count)
        #expect(PioAppIconService.registeredThemes[.basic] == nil)
        let project = try String(contentsOf: root.appendingPathComponent("Daylog.xcodeproj/project.pbxproj"), encoding: .utf8)
        let settings = project.components(separatedBy: "\n").filter { $0.contains("ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES") }
        #expect(settings.count == 2) // iOS 앱 타깃의 Debug·Release
        for outfit in premium {
            let name = try #require(PioAppIconService.registeredThemes[outfit])
            #expect(name == "AppIcon-\(outfit.rawValue)")
            for line in settings { #expect(line.contains(name), "\(name) 빌드 설정 누락") }
            let set = root.appendingPathComponent("Daylog/Assets.xcassets/\(name).appiconset")
            let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: set.appendingPathComponent("Contents.json"))) as? [String: Any]
            let images = try #require(contents?["images"] as? [[String: Any]])
            // iPhone 홈 화면(60pt @3x)과 iPad(83.5pt @2x) 크기가 있고, 파일이 실제로 있다.
            #expect(images.contains { $0["idiom"] as? String == "iphone" && $0["size"] as? String == "60x60" && $0["scale"] as? String == "3x" })
            #expect(images.contains { $0["idiom"] as? String == "ipad" && $0["size"] as? String == "83.5x83.5" })
            for image in images {
                let file = try #require(image["filename"] as? String)
                #expect(FileManager.default.fileExists(atPath: set.appendingPathComponent(file).path), "\(name)/\(file)")
            }
            // 옷장 미리보기 그림
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(
                "Daylog/PioWardrobe.xcassets/pio_icon_preview_\(outfit.rawValue).imageset/pio_icon_preview_\(outfit.rawValue).png").path))
        }
    }

    /// 빌드된 Info.plist에 대체 아이콘이 없으면 고를 수 없고, 소유하지 않은 의상의 아이콘도 고를 수 없다.
    @Test func unregisteredOrUnownedIconsCannotBeSelected() {
        for outfit in PioOutfitID.allCases where outfit != .basic {
            #expect(!PioAppIconService.isAvailable(outfit, info: [:]))
            #expect(!PioAppIconService.canSelect(outfit, store: PioWardrobeStore()))
        }
        #if os(iOS)
        let name = PioAppIconService.registeredThemes[.halloween]!
        let info: [String: Any] = ["CFBundleIcons": ["CFBundleAlternateIcons": [name: ["CFBundleIconName": name]]]]
        #expect(PioAppIconService.isAvailable(.halloween, info: info))
        #endif
    }

    @Test func cancellationIsSilentAndPendingNeverSaysOwned() {
        #expect(PioWardrobeEntitlementResult.cancelled.wardrobeMessage == nil)
        #expect(PioWardrobeEntitlementResult.pending.wardrobeMessage?.contains("승인") == true)
        #expect(PioWardrobeEntitlementResult.unverified.wardrobeMessage?.contains("잠겨") == true)
    }
}
