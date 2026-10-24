import XCTest
import QuartzCore
import CryptoKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Run in a separate process from the seven quiet performance methods: this
/// deliberately loads every original asset name to prove pixel identity.
@MainActor final class PioCloudTextureAliasesTests: XCTestCase {
    func testAllRegisteredProductionTexturesHaveIdempotentAliases() throws {
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        let aliases = PioCloudTextureAliases.aliases
        XCTAssertEqual(aliases.count, 146, "Regenerate and review the alias pack when the approved source set changes")
        XCTAssertEqual(Set(aliases.values).count, 44)
        for outfit in PioOutfitID.allCases {
            let registration = try XCTUnwrap(PioCloudSceneResources.productionRegistration(outfit: outfit))
            for part in registration.parts {
                let canonical = try XCTUnwrap(aliases[part.asset], "Missing mapping for \(part.asset)")
                XCTAssertEqual(PioCloudTextureAliases.canonicalName(for: canonical), canonical)
                XCTAssertNotNil(image(canonical), "Canonical image must exist")
            }
        }
        let legacy = try XCTUnwrap(PioCloudSceneResources.productionBasicRegistration())
        for part in legacy.parts { XCTAssertNotNil(aliases[part.asset]) }
        XCTAssertEqual(PioCloudTextureAliases.canonicalName(for: "unrelated_asset"), "unrelated_asset")
    }

    func testEveryCanonicalTextureHasIdenticalNativeDecodedPixels() throws {
        let aliases = PioCloudTextureAliases.aliases
        XCTAssertEqual(aliases.count, 146)
        var canonicalDigests: [String: [UInt8]] = [:]
        var compared = 0
        for (name, canonical) in aliases.sorted(by: { $0.key < $1.key }) {
            try autoreleasepool {
                let original = try XCTUnwrap(image(name), "Missing source \(name)")
                let shared = try XCTUnwrap(image(canonical), "Missing canonical \(canonical)")
                XCTAssertEqual(original.width, shared.width)
                XCTAssertEqual(original.height, shared.height)
                let expected: [UInt8]
                if let digest = canonicalDigests[canonical] { expected = digest }
                else {
                    expected = try pixelDigest(shared)
                    canonicalDigests[canonical] = expected
                }
                XCTAssertEqual(try pixelDigest(original), expected,
                    "Alias must preserve actual decoded pixels: \(name) -> \(canonical)")
                compared += 1
            }
        }
        XCTAssertEqual(compared, 146)
        XCTAssertEqual(canonicalDigests.count, 44)
    }

    private func image(_ name: String) -> CGImage? {
        #if os(macOS)
        NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        UIImage(named: name)?.cgImage
        #endif
    }
    private func pixelDigest(_ image: CGImage) throws -> [UInt8] {
        let bytesPerRow = image.width * 4
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        let data = try XCTUnwrap(context.data)
        return Array(SHA256.hash(data: Data(bytes: data, count: bytesPerRow * image.height)))
    }
}
