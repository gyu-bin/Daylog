import Testing
@testable import Daylog

struct PioProductRegistryTests {
    @Test func everyPaidOutfitMapsOnceAndBasicIsNotAProduct() {
        let expected = Set(PioOutfitID.allCases).subtracting([.basic])
        #expect(Set(PioProductRegistry.entries.map(\.outfit)) == expected)
        #expect(PioProductRegistry.entries.count == expected.count)
        #expect(PioProductRegistry.productIDs.count == expected.count)
        #expect(PioProductRegistry.productID(for: .basic) == nil)
        #expect(PioProductRegistry.outfit(for: "outfit.basic") == nil)
    }

    @Test func artworkAndPreferenceKeysRemainIndependentOfRegisteredProductNames() {
        let names: [(PioOutfitID, String)] = [
            (.cherryBlossom, "cherryblossom"), (.summerVacation, "summer"),
            (.fitness, "workout"), (.rainyDay, "rainy"), (.astronaut, "space")
        ]
        for (outfit, key) in names {
            #expect(PioProductRegistry.productID(for: outfit) == "outfit." + key)
            #expect(PioProductRegistry.outfit(for: "outfit." + key) == outfit)
            #expect(PioOutfitID(rawValue: outfit.rawValue) == outfit)
            #expect(PioProductRegistry.outfit(for: "com.mungyubin.daylog.ios.outfit." + outfit.rawValue) == nil)
        }
    }
}
