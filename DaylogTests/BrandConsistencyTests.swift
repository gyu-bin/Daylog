import Foundation
import Testing
@testable import Daylog

/// 브랜드·아이콘 정합성(2026-10-24 최종 정리). 사용자에게 보이는 이름은 RoutiMori 하나이고,
/// 앱 안의 브랜드 아이콘은 공식 앱 아이콘(피오)과 같은 그림이다. 내부 식별자(파일·번들·저장소 이름)의 Daylog는 그대로 둔다.
@MainActor
struct BrandConsistencyTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func swiftFiles(in folder: String) throws -> [URL] {
        let base = root.appendingPathComponent(folder)
        let enumerator = try #require(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// 화면에 그려지는 글자(Text·Label·Button·단추 이름·제목·위젯 이름)에 옛 이름이나 틀린 표기가 없다.
    @Test func userVisibleStringLiteralsUseTheExactBrand() throws {
        let visibleCall = try Regex(#"(Text|Label|Button|accessibilityLabel|accessibilityHint|navigationTitle|sheetTitle|configurationDisplayName|description|help)\(\s*(verbatim:\s*)?"([^"\n]*)""#)
        let wrong = ["Daylog", "Routimori", "ROUTIMORI", "Routi Mori", "루티모리"]
        var found: [String] = []
        var scanned = 0
        for folder in ["Daylog", "DaylogWidgets", "DaylogShared"] {
            for file in try swiftFiles(in: folder) {
                scanned += 1
                let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
                for (index, line) in lines.enumerated() {
                    let code = line.components(separatedBy: "//").first ?? line
                    for match in code.matches(of: visibleCall) {
                        let literal = String(match.output[3].substring ?? "")
                        if wrong.contains(where: literal.contains) {
                            found.append("\(file.lastPathComponent):\(index + 1) \(literal)")
                        }
                    }
                }
            }
        }
        // 소스를 실제로 읽었는지 확인한다(못 읽으면 아무것도 없다고 통과하는 빈 검사가 된다).
        #expect(scanned > 200, "읽은 Swift 파일 \(scanned)개")
        #expect(found.isEmpty, "옛 브랜드 표기:\n\(found.joined(separator: "\n"))")
    }

    /// Finder·Dock·메뉴 막대가 쓰는 이름: 현지화(ko) 이름이 RoutiMori이고, Finder가 그것을 쓰도록 켜져 있다.
    /// 번들 파일 이름(Daylog.app)은 업데이트·설치 경로 때문에 그대로라, 기본 표시 이름을 파일 이름과 맞춰야 Finder가 현지화 이름을 쓴다.
    @Test func macBundleNamesResolveToTheBrandInFinderAndDock() throws {
        let localized = Bundle.main.localizedInfoDictionary ?? [:]
        #expect(localized["CFBundleName"] as? String == AppBrand.name)
        #expect(localized["CFBundleDisplayName"] as? String == AppBrand.name)
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["LSHasLocalizedDisplayName"] as? Bool == true)
        let fileName = Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
        #expect(info["CFBundleDisplayName"] as? String == fileName, "기본 표시 이름이 파일 이름과 다르면 Finder가 현지화 이름을 무시한다")
        #expect(FileManager.default.displayName(atPath: Bundle.main.bundlePath) == AppBrand.name)
    }

    /// 앱 아이콘 구성: macOS 크기 10개와 iOS·iPadOS 1024 하나. 브랜드 아이콘은 iOS 1024와 같은 파일이고, 옛 나뭇잎 아이콘 파일은 없다.
    @Test func iconAssetsUseOnlyTheOfficialRoutiMoriIcon() throws {
        let assets = root.appendingPathComponent("Daylog/Assets.xcassets")
        let appIcon = assets.appendingPathComponent("AppIcon.appiconset")
        let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: appIcon.appendingPathComponent("Contents.json"))) as? [String: Any]
        let images = try #require(contents?["images"] as? [[String: Any]])
        #expect(images.filter { $0["idiom"] as? String == "mac" }.count == 10)
        #expect(images.contains { $0["platform"] as? String == "ios" && $0["size"] as? String == "1024x1024" })
        for image in images {
            let name = try #require(image["filename"] as? String)
            #expect(FileManager.default.fileExists(atPath: appIcon.appendingPathComponent(name).path), "\(name) 없음")
        }
        let brand = try Data(contentsOf: assets.appendingPathComponent("BrandIcon.imageset/RoutiMoriBrandIcon.png"))
        let official = try Data(contentsOf: appIcon.appendingPathComponent("icon_ios_1024.png"))
        #expect(brand == official)
        let all = FileManager.default.enumerator(atPath: assets.path)?.allObjects as? [String] ?? []
        #expect(all.contains("BrandIcon.imageset/RoutiMoriBrandIcon.png"), "에셋 폴더를 읽지 못했다(\(all.count)개)")
        let leftovers = all.filter { $0.contains("DaylogIcon") || $0.contains("DockIconDark") }
        #expect(leftovers.isEmpty, "옛 나뭇잎 아이콘 파일: \(leftovers)")
    }
}
