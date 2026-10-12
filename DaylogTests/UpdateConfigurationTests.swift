import Foundation
import Testing
@testable import Daylog

struct UpdateConfigurationTests {
    private var valid: [String: Any] {
        ["DaylogUpdatesEnabled": true,
         "SUFeedURL": "https://github.com/gyu-bin/Daylog/releases/latest/download/appcast.xml",
         "SUPublicEDKey": Data(repeating: 1, count: 32).base64EncodedString()]
    }

    @Test func requiresExplicitActivationAndPublicKey() {
        #expect(!UpdateConfiguration(info: [:]).isReady)
        var info = valid
        #expect(UpdateConfiguration(info: info).isReady)
        info["DaylogUpdatesEnabled"] = false
        #expect(!UpdateConfiguration(info: info).isReady)
        info = valid
        for key in ["", "not-a-key", Data(repeating: 0, count: 32).base64EncodedString(), Data(repeating: 1, count: 31).base64EncodedString()] {
            info["SUPublicEDKey"] = key
            #expect(!UpdateConfiguration(info: info).isReady)
        }
    }

    @Test func checkOutcomeSeparatesUpToDateFoundCanceledAndFailed() {
        let domain = UpdateCheckOutcome.sparkleErrorDomain
        // 새 버전 없음은 실패가 아니다.
        #expect(UpdateCheckOutcome.resolve(foundVersion: nil, errorDomain: domain, errorCode: 1001, errorMessage: "최신") == .upToDate)
        // 새 버전을 찾고 정상적으로 끝났다(설치했거나 나중에).
        #expect(UpdateCheckOutcome.resolve(foundVersion: "1.6.0", errorDomain: nil, errorCode: nil, errorMessage: nil) == .found(version: "1.6.0"))
        // 사용자가 설치를 취소했다: 새 버전이 있다는 사실만 남는다.
        #expect(UpdateCheckOutcome.resolve(foundVersion: "1.6.0", errorDomain: domain, errorCode: 4007, errorMessage: "취소") == .found(version: "1.6.0"))
        #expect(UpdateCheckOutcome.resolve(foundVersion: nil, errorDomain: domain, errorCode: 4007, errorMessage: "취소") == nil)
        // 내려받기·서명 검증·설치 실패는 메시지와 함께 실패로 남는다(새 버전을 찾았더라도).
        #expect(UpdateCheckOutcome.resolve(foundVersion: "1.6.0", errorDomain: domain, errorCode: 3001, errorMessage: "서명이 맞지 않아요")
            == .failed(message: "서명이 맞지 않아요"))
        #expect(UpdateCheckOutcome.resolve(foundVersion: nil, errorDomain: NSURLErrorDomain, errorCode: -1009, errorMessage: nil)
            == .failed(message: "업데이트를 확인하지 못했어요."))
        // 아무 일도 없이 끝났으면 알릴 것이 없다.
        #expect(UpdateCheckOutcome.resolve(foundVersion: nil, errorDomain: nil, errorCode: nil, errorMessage: nil) == nil)
    }

    @Test func settingsStatusTextCoversEveryState() {
        let notReady = UpdateCheckOutcome.statusText(isConfigured: false, outcome: nil, currentVersion: "1.5.1")
        #expect(notReady.contains("준비 중") && notReady.contains("GitHub"))
        #expect(UpdateCheckOutcome.statusText(isConfigured: true, outcome: .upToDate, currentVersion: "1.5.1").contains("최신 버전이에요 (1.5.1)"))
        #expect(UpdateCheckOutcome.statusText(isConfigured: true, outcome: .found(version: "1.6.0"), currentVersion: "1.5.1").contains("1.6.0"))
        #expect(UpdateCheckOutcome.statusText(isConfigured: true, outcome: .failed(message: "네트워크"), currentVersion: "1.5.1").contains("네트워크"))
        #expect(UpdateCheckOutcome.releasesPage?.host == "github.com")
    }

    @Test(arguments: ["http://github.com/gyu-bin/Daylog/releases/latest/download/appcast.xml",
                      "https://example.com/appcast.xml", "https://github.com/other/appcast.xml",
                      "https://user@github.com/gyu-bin/Daylog/releases/latest/download/appcast.xml",
                      "https://github.com/gyu-bin/Daylog/releases/latest/download/appcast.xml?feed=other"])
    func rejectsUnapprovedFeed(url: String) {
        var info = valid
        info["SUFeedURL"] = url
        #expect(!UpdateConfiguration(info: info).isReady)
    }
}
