// OFFLINE RENDER PREVIEW. Not an application screenshot or recording.
// Stage/style/CloudShape extracted verbatim except named-asset file resolution.
import AppKit
import SwiftUI
import QuartzCore
import ImageIO
import UniformTypeIdentifiers
let repo = "/Users/mungyubin/Desktop/Coding/Daylog"
enum SyncSceneKind: String, CaseIterable { case receiving, ready, trouble }
enum RoutimoriSyncStyle {
    static let green = Color(red: 0.28, green: 0.43, blue: 0.23)
    static func ink(dark: Bool) -> Color {
        dark ? Color(red: 0.85, green: 0.9, blue: 0.77) : Color(red: 0.21, green: 0.33, blue: 0.17)
    }
    static func background(dark: Bool) -> [Color] {
        dark ? [Color(red: 0.12, green: 0.15, blue: 0.12), Color(red: 0.08, green: 0.1, blue: 0.08)]
             : [Color(red: 0.98, green: 0.97, blue: 0.92), Color(red: 0.96, green: 0.94, blue: 0.87)]
    }
}
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            path.addEllipse(in: CGRect(x: rect.minX + x * w - r * w, y: rect.minY + y * h - r * w, width: 2 * r * w, height: 2 * r * w))
        }
        circle(0.2, 0.66, 0.16)
        circle(0.38, 0.42, 0.22)
        circle(0.62, 0.38, 0.24)
        circle(0.82, 0.64, 0.16)
        path.addRoundedRect(
            in: CGRect(x: rect.minX + 0.12 * w, y: rect.minY + 0.5 * h, width: 0.78 * w, height: 0.48 * h),
            cornerSize: CGSize(width: 0.24 * h, height: 0.24 * h)
        )
        return path
    }
}
@MainActor
final class RoutimoriSyncStage {
    struct Configuration: Equatable {
        var kind: SyncSceneKind
        var height: CGFloat
        var dark: Bool
        var scale: CGFloat
        var reduceMotion: Bool
    }
    let root = CALayer()
    let character = CALayer()
    let cloud = CALayer()
    let glyph = CALayer()
    private(set) var configuration: Configuration?
    private var isAnimating = false

    func update(_ configuration: Configuration, isAnimating: Bool) {
        let changed = self.configuration != configuration
        if changed {
            self.configuration = configuration
            build(configuration)
        }
        animate(isAnimating && !configuration.reduceMotion, force: changed)
    }

    func halt() { animate(false, force: true) }

    private func build(_ config: Configuration) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        root.bounds = CGRect(x: 0, y: 0, width: config.height, height: config.height)
        let u = config.height / 340
        for layer in [cloud, glyph, character] {
            layer.removeAllAnimations()
            layer.transform = CATransform3DIdentity
            layer.contentsScale = config.scale
            layer.contentsGravity = .resizeAspect
            root.addSublayer(layer)
        }
        cloud.bounds = CGRect(x: 0, y: 0, width: 160 * u, height: 90 * u)
        cloud.position = point(170 * u, 57 * u, config.height)
        cloud.contents = render(
            CloudShape().fill(LinearGradient(colors: [.white, Color(red: 0.91, green: 0.93, blue: 0.9)],
                                             startPoint: .top, endPoint: .bottom))
                .frame(width: 148 * u, height: 78 * u).padding(6 * u), scale: config.scale)
        cloud.shadowColor = CGColor(gray: 0, alpha: 1)
        cloud.shadowOpacity = config.dark ? 0.14 : 0.08
        cloud.shadowRadius = 5 * u
        cloud.shadowOffset = CGSize(width: 0, height: down(3 * u))

        let symbol: String = switch config.kind {
        case .receiving: "arrow.down"
        case .ready: "checkmark"
        case .trouble: "xmark"
        }
        let color = config.kind == .trouble ? Color(red: 0.78, green: 0.39, blue: 0.32) : RoutimoriSyncStyle.green
        glyph.bounds = CGRect(x: 0, y: 0, width: 46 * u, height: 46 * u)
        glyph.position = point(170 * u, (config.kind == .receiving ? 112 : 61) * u, config.height)
        glyph.contents = render(Image(systemName: symbol).font(.system(size: 32 * u, weight: .bold))
            .foregroundStyle(color).frame(width: 46 * u, height: 46 * u), scale: config.scale)

        let asset: String = switch config.kind {
        case .receiving: "routimori_sync_loading"
        case .ready: "routimori_sync_success"
        case .trouble: "routimori_sync_failure"
        }
        #if os(macOS)
        character.contents = NSImage(contentsOfFile: repo + "/Daylog/RoutimoriTrial.xcassets/\(asset).imageset/\(asset).png")?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        character.contents = UIImage(named: asset)?.cgImage
        #endif
        // Square canvas, aspect fit: source resolution is deliberately not assumed to be 1024.
        character.bounds = CGRect(x: 0, y: 0, width: 256 * u, height: 256 * u)
        character.position = point(170 * u, 226 * u, config.height)
    }

    private func animate(_ enabled: Bool, force: Bool) {
        guard let config = configuration, force || enabled != isAnimating else { return }
        isAnimating = enabled
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        for layer in [character, cloud, glyph] {
            layer.removeAllAnimations()
            layer.transform = CATransform3DIdentity
        }
        guard enabled else { return }
        let u = config.height / 340
        character.add(track("transform.scale", [1, 1.018, 1], duration: 3.8), forKey: "breathing")
        cloud.add(track("transform.translation.y", [0, down(-3 * u), 0], duration: 4.6), forKey: "float")
        switch config.kind {
        case .receiving:
            character.add(track("transform.rotation.z", [0, 0.018, 0, -0.018, 0], duration: 6), forKey: "attention")
            glyph.add(track("transform.translation.y", [down(-3 * u), down(5 * u), down(-3 * u)], duration: 1.8), forKey: "receiving")
        case .ready:
            character.add(track("transform.translation.y", [0, down(-10 * u), 0, down(-4 * u), 0],
                                duration: 1.4, repeats: false), forKey: "celebration")
            glyph.add(track("transform.scale", [1, 1.13, 1], duration: 1.1, repeats: false), forKey: "confirmation")
        case .trouble:
            // A single concerned tilt settles gently; an error must not shake forever.
            character.add(track("transform.rotation.z", [0, -0.045, 0.018, 0], duration: 2.3, repeats: false), forKey: "concern")
        }
    }

    private func track(_ keyPath: String, _ values: [CGFloat], duration: Double, repeats: Bool = true) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values.map { NSNumber(value: Double($0)) }
        animation.duration = duration
        animation.calculationMode = .linear
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: values.count - 1)
        animation.repeatCount = repeats ? .infinity : 0
        return animation
    }

    private func render<V: View>(_ view: V, scale: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.cgImage
    }

    private func point(_ x: CGFloat, _ y: CGFloat, _ height: CGFloat) -> CGPoint {
        #if os(macOS)
        CGPoint(x: x, y: height - y)
        #else
        CGPoint(x: x, y: y)
        #endif
    }
    private func down(_ value: CGFloat) -> CGFloat {
        #if os(macOS)
        -value
        #else
        value
        #endif
    }
}

@MainActor
struct SampledStage {
    let stage: RoutimoriSyncStage
    let tracks: [(CALayer, String, CAAnimation)]
    init(_ kind: SyncSceneKind, height: CGFloat, dark: Bool = false, reduceMotion: Bool = false) {
        let stage = RoutimoriSyncStage()
        stage.update(.init(kind: kind, height: height, dark: dark, scale: 2, reduceMotion: reduceMotion), isAnimating: true)
        var tracks: [(CALayer, String, CAAnimation)] = []
        for layer in [stage.character, stage.cloud, stage.glyph] {
            for key in layer.animationKeys() ?? [] {
                let a = layer.animation(forKey: key)!
                let path = (a as! CAPropertyAnimation).keyPath!
                tracks.append((layer, path, a))
            }
            layer.removeAllAnimations()
        }
        self.stage = stage
        self.tracks = tracks
    }
    func sample(_ time: Double) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (layer, path, animation) in tracks {
            guard let a = animation as? CAKeyframeAnimation,
                  let values = a.values as? [NSNumber] else { fatalError("Unsupported actual animation") }
            let duration = a.duration
            let t = a.repeatCount == .infinity ? time.truncatingRemainder(dividingBy: duration) : min(time, duration)
            let progress = t / duration * Double(values.count - 1)
            let index = min(values.count - 2, Int(progress))
            let local = progress - Double(index)
            let eased = ease(local, a.timingFunctions?[index])
            let value = values[index].doubleValue + (values[index + 1].doubleValue - values[index].doubleValue) * eased
            layer.setValue(value, forKeyPath: path)
        }
        CATransaction.commit()
        CATransaction.flush()
    }
}
// Invert the actual CAMediaTimingFunction x cubic to obtain its y at elapsed fraction.
func ease(_ x: Double, _ fn: CAMediaTimingFunction?) -> Double {
    guard let fn else { return x }
    var p1 = [Float](repeating: 0, count: 2), p2 = p1
    fn.getControlPoint(at: 1, values: &p1); fn.getControlPoint(at: 2, values: &p2)
    func cubic(_ t: Double, _ a: Double, _ b: Double) -> Double {
        3 * (1-t) * (1-t) * t * a + 3 * (1-t) * t * t * b + t*t*t
    }
    var lo = 0.0, hi = 1.0
    for _ in 0..<40 {
        let m = (lo+hi)/2
        if cubic(m, Double(p1[0]), Double(p2[0])) < x { lo = m } else { hi = m }
    }
    return cubic((lo+hi)/2, Double(p1[1]), Double(p2[1]))
}
func context(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:0,
              space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func png(_ image: CGImage, _ path: String) {
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath:path) as CFURL, UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(d,image,nil); precondition(CGImageDestinationFinalize(d))
}
@MainActor
func render(_ model: SampledStage, time: Double, dark: Bool = false) -> CGImage {
    model.sample(time)
    let side = model.stage.root.bounds.width
    let ctx = context(Int(side*2),Int(side*2))
    ctx.setFillColor(dark ? CGColor(red:0.12,green:0.15,blue:0.12,alpha:1) : CGColor(red:0.98,green:0.97,blue:0.92,alpha:1))
    ctx.fill(CGRect(x:0,y:0,width:side*2,height:side*2))
    ctx.scaleBy(x:2,y:2)
    // CALayer.render(in:) does not apply these sampled transform subkeys reliably in a headless tree.
    // Apply each actual model transform as a CGContext affine transform, then render its native content.
    for layer in model.stage.root.sublayers ?? [] {
        ctx.saveGState()
        ctx.translateBy(x: layer.position.x, y: layer.position.y)
        ctx.concatenate(CATransform3DGetAffineTransform(layer.transform))
        ctx.translateBy(x: -layer.bounds.width * layer.anchorPoint.x, y: -layer.bounds.height * layer.anchorPoint.y)
        layer.render(in: ctx)
        ctx.restoreGState()
    }
    return ctx.makeImage()!
}
@main struct Main {
 @MainActor static func main() throws {
    let out = repo + "/docs/qa/routimori-vacation-cloud-2026-10-16/cloud-render-preview"
    try FileManager.default.createDirectory(atPath:out+"/frames",withIntermediateDirectories:true)
    for kind in SyncSceneKind.allCases {
        for height: CGFloat in [220,340] {
            for dark in [false,true] {
                let model = SampledStage(kind,height:height,dark:dark,reduceMotion:true)
                png(render(model,time:0,dark:dark),out+"/\(kind.rawValue)-\(Int(height))-\(dark ? "dark" : "light")-still.png")
            }
        }
    }
    let models = SyncSceneKind.allCases.map { SampledStage($0,height:340) }
    for (kind,time) in [(SyncSceneKind.ready,0.35),(.trouble,2.3/3)] {
        let model = SampledStage(kind,height:340)
        model.sample(time)
        print(kind.rawValue, time, model.stage.character.transform)
        png(render(model,time:time),out+"/\(kind.rawValue)-accent-peak.png")
    }
    for frame in 0..<144 {
        let time = Double(frame)/24
        let ctx = context(2040,740)
        ctx.setFillColor(CGColor(red:0.98,green:0.97,blue:0.92,alpha:1))
        ctx.fill(CGRect(x:0,y:0,width:2040,height:740))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext:ctx,flipped:false)
        let caption = "OFFLINE RENDER PREVIEW · actual CA tracks · not an app recording"
        let attributes: [NSAttributedString.Key: Any] = [.font:NSFont.systemFont(ofSize:28,weight:.medium),.foregroundColor:NSColor.darkGray]
        let text = NSAttributedString(string:caption,attributes:attributes)
        text.draw(at:CGPoint(x:(2040-text.size().width)/2,y:700))
        NSGraphicsContext.restoreGraphicsState()
        for (index,model) in models.enumerated() {
            ctx.draw(render(model,time:time),in:CGRect(x:index*680,y:0,width:680,height:680))
        }
        png(ctx.makeImage()!,out+String(format:"/frames/%04d.png",frame))
    }
    print("Rendered 12 stills, 2 accent peaks, 144 frames at 24 fps from actual CA tracks.")
 }
}
