import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Registered eye components in the existing vacation CALayer tree. Original
/// foreground pixels remain the authority outside the two reconstructed regions.
@MainActor final class PioVacationIndependentEyes {
    let root = CALayer()
    let openEyes: [CALayer]
    let closedEyes: [CALayer]
    let halfEyes: [CALayer]
    enum ArtworkProfile { case basicDay, basicNight, christmasNight, christmasDay, winterNight }
    private let profile: ArtworkProfile
    private var requestedAnimation = false
    private var running = false
    var animationCount: Int {
        (openEyes + closedEyes + halfEyes).reduce(0) { $0 + ($1.animationKeys()?.count ?? 0) }
    }

    init?(originalForeground: CGImage, profile: ArtworkProfile = .basicDay) {
        self.profile = profile
        func image(_ name: String) -> CGImage? {
            #if os(macOS)
            return NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            #else
            return UIImage(named: name)?.cgImage
            #endif
        }
        let names: (clean: String, left: String, right: String, half: String?)
        let regions: [CGRect]
        switch profile {
        case .basicDay:
            names = ("pio_vacation_basic_day_clean_v1", "pio_vacation_basic_day_open_left_v1",
                     "pio_vacation_basic_day_open_right_v1", nil)
            regions = [CGRect(x: 422, y: 688, width: 58, height: 44), CGRect(x: 531, y: 647, width: 54, height: 43)]
        case .basicNight:
            names = ("pio_vacation_basic_night_clean_v1", "pio_vacation_basic_night_open_v1",
                     "pio_vacation_basic_night_open_v1", "pio_vacation_basic_night_half_v2")
            regions = [CGRect(x: 419, y: 781, width: 65, height: 57), CGRect(x: 547, y: 732, width: 63, height: 54)]
        case .christmasDay:
            names = ("pio_vacation_christmas_day_clean_v1", "pio_vacation_christmas_day_open_v1",
                     "pio_vacation_christmas_day_open_v1", nil)
            regions = [CGRect(x: 441, y: 720, width: 65, height: 57), CGRect(x: 553, y: 682, width: 61, height: 50)]
        case .winterNight:
            names = ("pio_vacation_winter_night_clean_v1", "pio_vacation_winter_night_open_v1",
                     "pio_vacation_winter_night_open_v1", nil)
            regions = [CGRect(x: 446, y: 802, width: 77, height: 65), CGRect(x: 588, y: 756, width: 69, height: 57)]
        case .christmasNight:
            names = ("pio_vacation_christmas_night_clean_v1", "pio_vacation_christmas_night_open_v1",
                     "pio_vacation_christmas_night_open_v1", nil)
            regions = [CGRect(x: 435, y: 743, width: 78, height: 72), CGRect(x: 574, y: 704, width: 71, height: 62)]
        }
        guard originalForeground.width == 1024, originalForeground.height == 1536,
              let clean = image(names.clean), let left = image(names.left), let right = image(names.right),
              clean.width == 1024, clean.height == 1536 else { return nil }
        let half = names.half.flatMap { image($0) }
        if profile != .basicDay && (left.width != 1024 || left.height != 1536 || right.width != 1024 || right.height != 1536) { return nil }
        if names.half != nil && (half?.width != 1024 || half?.height != 1536) { return nil }
        // Vacation root is flipped on Mac and uses top-left sampling, as UIKit
        // does. Do not copy the unflipped Mac cloud sampler's Y conversion.
        func sample(_ texture: CGImage, rect: CGRect, target: CGRect? = nil, feather: CGFloat = 0) -> CALayer {
            let layer = CALayer(); layer.contents = texture; layer.frame = target ?? rect
            layer.contentsGravity = .resize; layer.minificationFilter = .trilinear
            layer.contentsRect = CGRect(x: rect.minX / 1024, y: rect.minY / 1536,
                                        width: rect.width / 1024, height: rect.height / 1536)
            if feather > 0 {
                let horizontal = CAGradientLayer(); horizontal.frame = layer.bounds
                horizontal.startPoint = CGPoint(x: 0, y: 0.5); horizontal.endPoint = CGPoint(x: 1, y: 0.5)
                horizontal.colors = [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 1),
                                     CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)]
                let x = feather / layer.bounds.width
                horizontal.locations = [0, NSNumber(value: Double(x)), NSNumber(value: Double(1 - x)), 1]
                let vertical = CAGradientLayer(); vertical.frame = layer.bounds; vertical.colors = horizontal.colors
                let y = feather / layer.bounds.height
                vertical.locations = [0, NSNumber(value: Double(y)), NSNumber(value: Double(1 - y)), 1]
                horizontal.mask = vertical; layer.mask = horizontal
            }
            return layer
        }
        let slots = [CGRect(x: 431, y: 687, width: 37.8, height: 43.8),
                     CGRect(x: 540, y: 647, width: 35.2, height: 40.8)]
        switch profile {
        case .basicNight:
            openEyes = regions.map { sample(left, rect: $0) }
            halfEyes = half.map { texture in regions.map { sample(texture, rect: $0) } } ?? []
        case .christmasDay:
            openEyes = [
                sample(left, rect: CGRect(x: 450, y: 723, width: 48, height: 48),
                       target: CGRect(x: 450, y: 727.5, width: 48, height: 48), feather: 3),
                sample(right, rect: CGRect(x: 557, y: 686, width: 43, height: 46),
                       target: CGRect(x: 562.5, y: 686, width: 43, height: 46), feather: 3)]
            halfEyes = []
        case .winterNight:
            openEyes = [
                sample(left, rect: CGRect(x: 458, y: 803, width: 58, height: 60),
                       target: CGRect(x: 455.5, y: 806.5, width: 58, height: 60), feather: 3),
                sample(right, rect: CGRect(x: 592, y: 761, width: 47, height: 51),
                       target: CGRect(x: 599, y: 758.5, width: 47, height: 51), feather: 3)]
            halfEyes = []
        case .christmasNight:
            // The generated eye pixels have their own measured source rectangles.
            // Reposition those samples to the original eye centers; never reuse
            // Basic's offsets for a different authored face.
            openEyes = [
                sample(left, rect: CGRect(x: 452, y: 749, width: 45, height: 53),
                       target: CGRect(x: 450.5, y: 755, width: 45, height: 53), feather: 3),
                sample(right, rect: CGRect(x: 576, y: 708, width: 40, height: 51),
                       target: CGRect(x: 588, y: 712, width: 40, height: 51), feather: 3)]
            halfEyes = []
        case .basicDay:
            openEyes = zip([left, right], slots).map { texture, rect in
                let layer = CALayer(); layer.contents = texture; layer.frame = rect
                layer.contentsGravity = .resizeAspect; layer.minificationFilter = .trilinear
                layer.opacity = 0; return layer
            }
            halfEyes = []
        }
        for layer in openEyes + halfEyes { layer.opacity = 0 }
        closedEyes = regions.map { sample(originalForeground, rect: $0) }
        root.frame = CGRect(x: 0, y: 0, width: 1024, height: 1536)
        switch profile {
        case .basicDay: root.name = "basicDayIndependentEyes"
        case .basicNight: root.name = "basicNightIndependentEyes"
        case .christmasNight: root.name = "christmasNightIndependentEyes"
        case .christmasDay: root.name = "christmasDayIndependentEyes"
        case .winterNight: root.name = "winterNightIndependentEyes"
        }
        for region in regions { root.addSublayer(sample(clean, rect: region, feather: profile != .basicDay && profile != .basicNight ? 3 : 0)) }
        for layer in openEyes + halfEyes + closedEyes { root.addSublayer(layer) }
        // At rest, preserve the exact original smiling eye regions.
        root.isHidden = true
    }

    func setVisible(_ visible: Bool) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.isHidden = !visible
        CATransaction.commit()
        setAnimating(requestedAnimation)
    }

    func setAnimating(_ active: Bool) {
        requestedAnimation = active
        let shouldRun = active && !root.isHidden
        guard shouldRun != running else { return }
        running = shouldRun
        for layer in openEyes + closedEyes + halfEyes { layer.removeAllAnimations() }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for layer in openEyes + halfEyes { layer.opacity = 0 }
        for layer in closedEyes { layer.opacity = 1 }
        CATransaction.commit()
        guard shouldRun else { return }
        if profile != .basicDay && profile != .basicNight {
            // Two genuine expression states; no invented half-lid for this outfit.
            let times: [NSNumber] = [0, 0.205, 0.39, 0.44, 0.58, 1]
            let values: [NSNumber] = [0, 1, 0, 1, 0, 0]
            let epoch = CACurrentMediaTime()
            for (layers, inverse) in [(openEyes, false), (closedEyes, true)] {
                for layer in layers {
                    let animation = CAKeyframeAnimation(keyPath: "opacity")
                    animation.values = values.map { inverse ? NSNumber(value: 1 - $0.doubleValue) : $0 }
                    animation.keyTimes = times; animation.calculationMode = .discrete
                    animation.duration = 9.2; animation.repeatCount = .infinity
                    animation.beginTime = layer.convertTime(epoch, from: nil)
                    layer.add(animation, forKey: "vacationEyeExpression")
                }
            }
            return
        }
        if profile == .basicNight {
            // One-hot full-expression regions: never blend two pupils together.
            // Half lids exist only as brief blink intermediates, not a resting mood.
            let states = [0, 1, 2, 1, 0, 1, 2, 1, 0, 0]
            let times: [NSNumber] = [0, 0.19, 0.205, 0.39, 0.405, 0.425, 0.44, 0.58, 0.595, 1]
            let epoch = CACurrentMediaTime()
            for (layers, state) in [(closedEyes, 0), (halfEyes, 1), (openEyes, 2)] {
                for layer in layers {
                    let animation = CAKeyframeAnimation(keyPath: "opacity")
                    animation.values = states.map { NSNumber(value: $0 == state ? 1 : 0) }
                    animation.keyTimes = times; animation.calculationMode = .discrete
                    animation.duration = 9.2; animation.repeatCount = .infinity
                    animation.beginTime = layer.convertTime(epoch, from: nil)
                    layer.add(animation, forKey: "vacationEyeExpression")
                }
            }
            return
        }
        // Resting smile, brief open glance, gentle blink, then return. This is
        // deliberately independent of the unchanged 7.6-second hammock sway.
        let times: [NSNumber] = [0, 0.19, 0.205, 0.39, 0.405, 0.425, 0.44, 0.58, 0.595, 1]
        let values: [NSNumber] = [0, 0, 1, 1, 0, 0, 1, 1, 0, 0]
        let epoch = CACurrentMediaTime()
        for (layers, inverse) in [(openEyes, false), (closedEyes, true)] {
            for layer in layers {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = values.map { inverse ? NSNumber(value: 1 - $0.doubleValue) : $0 }
                animation.keyTimes = times
                animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: times.count - 1)
                animation.duration = 9.2; animation.repeatCount = .infinity
                animation.beginTime = layer.convertTime(epoch, from: nil)
                layer.add(animation, forKey: "vacationEyeExpression")
            }
        }
    }
}
