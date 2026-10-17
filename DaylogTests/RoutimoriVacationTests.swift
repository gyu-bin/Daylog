import Testing
import QuartzCore
@testable import Daylog

@MainActor
struct RoutimoriVacationTests {
    @Test func swayStopsRestoresAndNeverAnimatesTheBeach() {
        let rig = RoutimoriVacationRig(background: nil, foreground: nil)
        for _ in 0..<2 {
            rig.setAnimating(true)
            rig.setAnimating(true)
            #expect(rig.hammock.animationKeys() == ["hammockSway"])
            #expect(rig.beach.animationKeys()?.isEmpty ?? true)
            #expect(rig.canvas.animationKeys()?.isEmpty ?? true)
            rig.setAnimating(false)
            #expect(rig.hammock.animationKeys()?.isEmpty ?? true)
            #expect(CATransform3DIsIdentity(rig.hammock.transform))
        }
    }

    @Test func registeredImagesStayAlignedAndTheRopeAnchorDoesNotMove() {
        let rig = RoutimoriVacationRig(background: nil, foreground: nil)
        rig.layout(in: CGRect(x: 0, y: 0, width: 390, height: 780),
                   slot: CGRect(x: 20, y: 250, width: 350, height: 250), isDark: false, displayScale: 3)
        let source = CGPoint(x: 600, y: 900)
        let foregroundPoint = rig.hammock.convert(source, to: rig.canvas)
        let beachPoint = rig.beach.convert(source, to: rig.canvas)
        #expect(abs(foregroundPoint.x - beachPoint.x) < 0.0001)
        #expect(abs(foregroundPoint.y - beachPoint.y) < 0.0001)
        let anchor = RoutimoriVacationRig.attachment
        for angle in [-RoutimoriVacationRig.swingDegrees, RoutimoriVacationRig.swingDegrees] {
            rig.hammock.transform = CATransform3DMakeRotation(angle * .pi / 180, 0, 0, 1)
            let mapped = rig.hammock.convert(anchor, to: rig.canvas)
            #expect(abs(mapped.x - anchor.x) < 0.0001)
            #expect(abs(mapped.y - anchor.y) < 0.0001)
            #expect(CATransform3DIsIdentity(rig.beach.transform))
        }
    }

    @Test func changingTimeOfDaySelectsRegisteredArtworkWithoutRestartingSway() throws {
        func image(_ gray: CGFloat) throws -> CGImage {
            let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(gray: gray, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            return try #require(context.makeImage())
        }
        let dayBackground = try image(0.9), dayForeground = try image(0.8)
        let nightBackground = try image(0.1), nightForeground = try image(0.6)
        let rig = RoutimoriVacationRig(background: dayBackground, foreground: dayForeground,
            nightBackground: nightBackground, nightForeground: nightForeground)
        rig.setAnimating(true)
        // A sentinel beginTime detects replacing the installed animation on layout.
        let installedSway = try #require(rig.hammock.animation(forKey: "hammockSway"))
        let sway = try #require(installedSway.copy() as? CAAnimation)
        sway.beginTime = 123
        rig.hammock.add(sway, forKey: "hammockSway")
        let slot = CGRect(x: 20, y: 250, width: 350, height: 250)
        for night in [false, true, false] {
            rig.layout(in: CGRect(x: 0, y: 0, width: 390, height: 780),
                slot: slot, isDark: night, displayScale: 3)
            #expect((rig.beach.contents as AnyObject?) === (night ? nightBackground : dayBackground))
            #expect((rig.hammock.contents as AnyObject?) === (night ? nightForeground : dayForeground))
            let anchor = night ? RoutimoriVacationRig.nightAttachment : RoutimoriVacationRig.attachment
            let focus = night ? RoutimoriVacationRig.nightHammockFocus : RoutimoriVacationRig.hammockFocus
            #expect(rig.hammock.position == anchor)
            let mapped = rig.hammock.convert(anchor, to: rig.canvas)
            #expect(abs(mapped.x - anchor.x) < 0.0001 && abs(mapped.y - anchor.y) < 0.0001)
            let focusOnScreen = rig.canvas.convert(focus, to: rig.root)
            #expect(abs(focusOnScreen.x - slot.midX) < 0.0001 && abs(focusOnScreen.y - slot.midY) < 0.0001)
            #expect(rig.hammock.animation(forKey: "hammockSway")?.beginTime == 123)
            #expect(rig.root.sublayers?.count == 1) // No blanket color-filter layer.
        }
        rig.setAnimating(false)
    }
}
