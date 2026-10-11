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
