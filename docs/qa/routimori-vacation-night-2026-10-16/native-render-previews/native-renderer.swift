import AppKit
import QuartzCore
@MainActor
final class RoutimoriVacationRig {
    // Both images share this source registration; neither image is independently
    // cropped or stretched. The resting hammock therefore matches the beach.
    static let sourceSize = CGSize(width: 1024, height: 1536)
    static let hammockFocus = CGPoint(x: 512, y: 740)
    static let attachment = CGPoint(x: 968, y: 484)
    static let nightHammockFocus = CGPoint(x: 512, y: 845)
    static let nightAttachment = CGPoint(x: 68, y: 465)
    static let swingDegrees: CGFloat = 1.5
    let root = CALayer()
    let canvas = CALayer()
    let beach = CALayer()
    let hammock = CALayer()
    private let dayBackground: CGImage?
    private let dayForeground: CGImage?
    private let nightBackground: CGImage?
    private let nightForeground: CGImage?
    private var isAnimating = false

    init(background: CGImage?, foreground: CGImage?, nightBackground: CGImage? = nil, nightForeground: CGImage? = nil) {
        dayBackground = background
        dayForeground = foreground
        self.nightBackground = nightBackground
        self.nightForeground = nightForeground
        #if os(macOS)
        root.isGeometryFlipped = true
        #endif
        root.masksToBounds = true
        root.addSublayer(canvas)
        canvas.anchorPoint = .zero
        canvas.bounds = CGRect(origin: .zero, size: Self.sourceSize)
        // Fade the portrait's outer edges into the surrounding cream on wide
        // panes. This stationary mask includes both registered layers, so the
        // character keeps its intended size and the rope cannot reveal a seam.
        let horizontalFade = CAGradientLayer()
        horizontalFade.frame = canvas.bounds
        horizontalFade.startPoint = CGPoint(x: 0, y: 0.5)
        horizontalFade.endPoint = CGPoint(x: 1, y: 0.5)
        horizontalFade.colors = [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 1),
                                 CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)]
        horizontalFade.locations = [0, 0.075, 0.925, 1]
        let verticalFade = CAGradientLayer()
        verticalFade.frame = canvas.bounds
        verticalFade.colors = horizontalFade.colors
        verticalFade.locations = [0, 0.06, 0.94, 1]
        horizontalFade.mask = verticalFade
        canvas.mask = horizontalFade
        for layer in [beach, hammock] {
            layer.bounds = canvas.bounds
            layer.contentsGravity = .resize
            layer.minificationFilter = .trilinear
            canvas.addSublayer(layer)
        }
        beach.position = CGPoint(x: Self.sourceSize.width / 2, y: Self.sourceSize.height / 2)
        beach.contents = background
        hammock.anchorPoint = CGPoint(x: Self.attachment.x / Self.sourceSize.width,
                                      y: Self.attachment.y / Self.sourceSize.height)
        hammock.position = Self.attachment
        hammock.contents = foreground
    }

    func layout(in bounds: CGRect, slot: CGRect?, isDark: Bool, displayScale: CGFloat) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let target = slot ?? CGRect(x: bounds.width * 0.05, y: bounds.height * 0.3,
                                   width: bounds.width * 0.9, height: bounds.width * 0.64)
        let scale = max(target.width, 1) / Self.sourceSize.width
        // Switch a complete registered pair together. Missing preview assets fall
        // back to the day pair rather than leaving an empty layer or mismatched rig.
        let usesNightArtwork = isDark && nightBackground != nil && nightForeground != nil
        let focus = usesNightArtwork ? Self.nightHammockFocus : Self.hammockFocus
        let anchor = usesNightArtwork ? Self.nightAttachment : Self.attachment
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = bounds
        root.backgroundColor = isDark
            ? CGColor(red: 0.025, green: 0.065, blue: 0.12, alpha: 1)
            : CGColor(red: 0.98, green: 0.97, blue: 0.92, alpha: 1)
        beach.contents = usesNightArtwork ? nightBackground : dayBackground
        hammock.contents = usesNightArtwork ? nightForeground : dayForeground
        hammock.anchorPoint = CGPoint(x: anchor.x / Self.sourceSize.width, y: anchor.y / Self.sourceSize.height)
        hammock.position = anchor
        canvas.position = CGPoint(x: target.midX - focus.x * scale,
                                  y: target.midY - focus.y * scale)
        canvas.transform = CATransform3DMakeScale(scale, scale, 1)
        for layer in [root, beach, hammock] { layer.contentsScale = max(displayScale, 1) }
        CATransaction.commit()
    }

    func setAnimating(_ active: Bool) {
        guard active != isAnimating else { return }
        isAnimating = active
        if active {
            let swing = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle = Self.swingDegrees * .pi / 180
            swing.values = [0, angle, 0, -angle, 0]
            swing.keyTimes = [0, 0.25, 0.5, 0.75, 1]
            swing.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
            swing.duration = 7.6
            swing.repeatCount = .infinity
            hammock.add(swing, forKey: "hammockSway")
        } else {
            hammock.removeAllAnimations()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hammock.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }
}

MainActor.assumeIsolated {
func load(_ name: String) -> CGImage? {
 let url = URL(fileURLWithPath: "Daylog/RoutimoriTrial.xcassets/\(name).imageset/\(name).png")
 guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
 return CGImageSourceCreateImageAtIndex(src, 0, nil)
}
let rig = RoutimoriVacationRig(background: load("routimori_vacation_background"), foreground: load("routimori_vacation_hammock"), nightBackground: load("routimori_vacation_background_night"), nightForeground: load("routimori_vacation_hammock_night"))
let size = CGSize(width: 390, height: 844)
rig.layout(in: CGRect(origin: .zero, size: size), slot: CGRect(x: 10, y: 250, width: 370, height: 264), isDark: true, displayScale: 3)

rig.setAnimating(true)
let track = rig.hammock.animation(forKey: "hammockSway") as! CAKeyframeAnimation
let values = (track.values as! [NSNumber]).map { CGFloat($0.doubleValue) }
let times = track.keyTimes!.map { $0.doubleValue }
let curves = track.timingFunctions!
rig.setAnimating(false)
func cubic(_ t: Double, _ a: Double, _ b: Double) -> Double {
 let u = 1 - t
 return 3*u*u*t*a + 3*u*t*t*b + t*t*t
}
func eased(_ progress: Double, _ curve: CAMediaTimingFunction) -> Double {
 var p1: [Float] = [0,0]; var p2: [Float] = [0,0]
 curve.getControlPoint(at: 1, values: &p1); curve.getControlPoint(at: 2, values: &p2)
 var lo = 0.0; var hi = 1.0
 for _ in 0..<30 {
  let mid = (lo + hi) / 2
  if cubic(mid, Double(p1[0]), Double(p2[0])) < progress { lo = mid } else { hi = mid }
 }
 return cubic((lo+hi)/2, Double(p1[1]), Double(p2[1]))
}
let frames = 92
let url = URL(fileURLWithPath: "/tmp/routimori-vacation-night-native-track.gif")
let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, frames, nil)!
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for frame in 0..<frames {
 let progress = Double(frame) / Double(frames)
 let index = min(times.count - 2, times.lastIndex(where: { $0 <= progress }) ?? 0)
 let local = (progress - times[index]) / (times[index+1] - times[index])
 let angle = values[index] + (values[index+1] - values[index]) * eased(local, curves[index])
 rig.hammock.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
 let context = CGContext(data: nil, width: 390, height: 844, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
 context.translateBy(x: 0, y: 844); context.scaleBy(x: 1, y: -1)
 rig.root.render(in: context)
 CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: track.duration / Double(frames)]] as CFDictionary)
}
CGImageDestinationFinalize(destination)
print("Exact native rig, values/keyTimes/duration/control points sampled from installed CAKeyframeAnimation. This is an offline compositor preview, not a running-app recording.")
print(url.path)
}
