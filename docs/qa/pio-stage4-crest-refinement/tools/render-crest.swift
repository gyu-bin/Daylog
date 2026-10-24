// Standalone offline QA renderer. No application code or asset catalog is changed.
// swiftc -O Tools/pio-rig/validate-stage4.swift -o /tmp/pio-stage4-validator
// /tmp/pio-stage4-validator <candidate-directory> <output-directory> [repository-root] 
import AppKit
import QuartzCore
import ImageIO
import UniformTypeIdentifiers
import Accelerate

let args = CommandLine.arguments
guard args.count >= 3 else { fatalError("Usage: validate-stage4 <candidates> <output> [repo]") }
let candidates = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let repo = URL(fileURLWithPath: args.count > 3 && !args[3].hasPrefix("--") ? args[3] : FileManager.default.currentDirectoryPath)
// Stage 1–3 are locked to their approved application configuration.
// Only Stage 4 candidate registration may be tuned through these environment values.
let env = ProcessInfo.processInfo.environment
func setting(_ name: String, _ fallback: Double) -> CGFloat {
    guard let raw = env[name] else { return CGFloat(fallback) }
    guard let value = Double(raw), value.isFinite else { fatalError("Invalid numeric setting: \(name)") }
    return CGFloat(value)
}
let wingScale4 = setting("STAGE4_WING_SCALE", 0.72)
let sourceLeftX4 = setting("STAGE4_SOURCE_LEFT_X", 481.95)
let sourceRightX4 = setting("STAGE4_SOURCE_RIGHT_X", 1054.05)
let sourceY4 = setting("STAGE4_SOURCE_Y", 940.05)
let cropAllowance4 = setting("STAGE4_CROP_ALLOWANCE", 27)
precondition(wingScale4 > 0 && cropAllowance4 >= 0)
let fm = FileManager.default
try fm.createDirectory(at: output, withIntermediateDirectories: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let canvas: CGFloat = 1536
let fitted: CGFloat = 1228.5
let footBottom = CGPoint(x: 755.25, y: 1354.5)
let imageCenter = CGPoint(x: 755.25, y: 740.25)
var sourceCache: [String: CGImage] = [:]
func load(_ path: URL) -> CGImage {
    if let cached = sourceCache[path.path] { return cached }
    guard let src = CGImageSourceCreateWithURL(path as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("Missing/unreadable image: \(path.path)") }
    guard img.width == 1536 && img.height == 1536 else { fatalError("Expected 1536 canvas: \(path.path), got \(img.width)x\(img.height)") }
    sourceCache[path.path] = img
    return img
}
func original(_ part: String, stage: Int = 1) -> CGImage {
    let suffix = stage >= 2 && part.hasPrefix("wing_") ? "_2" : ""
    let name = "pio_rig_" + part + suffix
    return load(repo.appendingPathComponent("Daylog/PioTrial.xcassets/\(name).imageset/\(name).png"))
}
func newPart(_ part: String, stage: Int) -> CGImage {
    let name = "pio_stage\(stage)_\(part)"
    return load(stage == 4 ? candidates.appendingPathComponent("\(name).png") :
        repo.appendingPathComponent("Daylog/PioTrial.xcassets/\(name).imageset/\(name).png"))
}
func context(_ width: Int, _ height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func write(_ image: CGImage, _ name: String) {
    let url = output.appendingPathComponent(name)
    try! fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Failed writing \(url.path)") }
}
struct Pose {
    var name: String
    var left: CGFloat = 0
    var right: CGFloat = 0
    var crest: CGFloat = 0
    var bob: CGFloat = 0 // fraction of fitted character size
    var footLift: CGFloat = 0
    var sx: CGFloat = 1
    var sy: CGFloat = 1
}
// Jump and landing sample existing bigHop tracks linearly at t=.32 and .56.
// Animation easing and continuous idle sway are intentionally absent from static samples.
let poses = [
    Pose(name: "neutral"), Pose(name: "wings-48", left: 48, right: 48),
    Pose(name: "wave-62", left: 7, right: 62), Pose(name: "crest-minus12", crest: -12),
    Pose(name: "crest-plus12", crest: 12),
    Pose(name: "jump", left: 46.4, right: 41.6, crest: -3.733333, bob: 0.34, footLift: 0.05),
    Pose(name: "landing", left: 23.4, right: 24.75, crest: 16.625, sx: 1.1, sy: 0.86)
]
let backgrounds: [(String, NSColor)] = [("light", NSColor(srgbRed: 0.97, green: 0.96, blue: 0.94, alpha: 1)),
                                        ("dark", NSColor(srgbRed: 0.13, green: 0.145, blue: 0.17, alpha: 1))]
// Exact crop/downsample approach from SaessagiRenderer: shared crop, bottom aligned,
// 2pt padding, vImage high quality resampling per image before CALayer transforms.
func downsample(_ source: CGImage, size: CGFloat, scale: CGFloat, padding: CGFloat) -> CGImage {
    let side = Int(((size + padding * 2) * scale).rounded())
    let fittedPixels = Int((size * scale).rounded())
    let cropSide = Int((fitted * CGFloat(side) / CGFloat(fittedPixels)).rounded())
    let margin = (CGFloat(cropSide) - fitted) / 2
    let crop = context(cropSide, cropSide), dst = context(side, side)
    crop.interpolationQuality = .none
    crop.draw(source, in: CGRect(x: (CGFloat(cropSide) / 2 - footBottom.x).rounded(),
                               y: (margin - (canvas - footBottom.y)).rounded(), width: canvas, height: canvas))
    var input = vImage_Buffer(data: crop.data!, height: UInt(cropSide), width: UInt(cropSide), rowBytes: crop.bytesPerRow)
    var result = vImage_Buffer(data: dst.data!, height: UInt(side), width: UInt(side), rowBytes: dst.bytesPerRow)
    precondition(vImageScale_ARGB8888(&input, &result, nil, vImage_Flags(kvImageHighQualityResampling)) == kvImageNoError)
    return dst.makeImage()!
}
func render(stage: Int, pose: Pose, bg: NSColor, size: CGFloat? = nil, scale: CGFloat = 1) -> CGImage {
    let native = size == nil
    let padding: CGFloat = !native && stage >= 3 ? max(2, ceil(size! * (stage == 4 ? cropAllowance4 : 27) / fitted)) : 2
    let side = native ? canvas : size! + padding * 2
    // Native jump keeps full 1536-pixel source detail and reserves headroom rather than clipping flight.
    let headroom: CGFloat = pose.bob > 0 ? (native ? 512 : ceil(size! * 512 / fitted)) : 0
    let height = side + headroom
    let ctx = context(Int((side * scale).rounded()), Int((height * scale).rounded()))
    ctx.setFillColor(bg.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
    ctx.scaleBy(x: scale, y: scale)
    let root = CALayer(); root.bounds = CGRect(x: 0, y: 0, width: side, height: height)
    func point(_ p: CGPoint) -> CGPoint {
        if native { return CGPoint(x: p.x, y: side - p.y) }
        let k = size! / fitted
        let x = size! / 2 + (p.x - footBottom.x) * k + padding
        let y = size! - (footBottom.y - p.y) * k + padding
        return CGPoint(x: x, y: side - y)
    }
    func layer(_ parent: CALayer, anchor: CGPoint, image: CGImage? = nil) -> CALayer {
        let l = CALayer(), p = point(anchor)
        l.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        l.anchorPoint = CGPoint(x: p.x / side, y: p.y / side)
        l.position = p
        if let image {
            l.contents = native ? image : downsample(image, size: size!, scale: scale, padding: padding)
            l.contentsScale = scale; l.contentsGravity = .resize
        }
        parent.addSublayer(l)
        return l
    }
    func rotate(_ l: CALayer, clockwise: CGFloat) { l.setValue(-clockwise * .pi / 180, forKeyPath: "transform.rotation.z") }
    CATransaction.begin(); CATransaction.setDisableActions(true)
    let mover = layer(root, anchor: footBottom)
    mover.setValue(pose.bob * (native ? fitted : size!), forKeyPath: "transform.translation.y")
    mover.setValue(pose.sx, forKeyPath: "transform.scale.x")
    mover.setValue(pose.sy, forKeyPath: "transform.scale.y")
    let breather = layer(mover, anchor: footBottom)
    let fl = layer(breather, anchor: CGPoint(x: 615, y: 1242), image: original("foot_left"))
    let fr = layer(breather, anchor: CGPoint(x: 918, y: 1242), image: original("foot_right"))
    for foot in [fl, fr] { foot.setValue(pose.footLift * (native ? fitted : size!), forKeyPath: "transform.translation.y") }
    let torso = layer(breather, anchor: CGPoint(x: 768, y: 1230))
    func crest() {
        let l = layer(torso, anchor: CGPoint(x: 745.05, y: 588), image: stage >= 3 ? newPart("crest", stage: stage) : original("crest"))
        rotate(l, clockwise: pose.crest)
    }
    if stage >= 3 {
        crest()
        for name in ["tail_left", "tail_right"] { _ = layer(torso, anchor: imageCenter, image: newPart(name, stage: stage)) }
    }
    func wings() {
    for (name, pivot, angle, sign) in [("left", CGPoint(x: stage == 4 ? sourceLeftX4 : 481.95, y: stage == 4 ? sourceY4 : 940.05), pose.left, CGFloat(1)),
                                       ("right", CGPoint(x: stage == 4 ? sourceRightX4 : 1054.05, y: stage == 4 ? sourceY4 : 940.05), pose.right, CGFloat(-1))] {
        let mount = layer(torso, anchor: pivot)
        let adjusted = stage >= 2
        if adjusted {
            mount.position = point(CGPoint(x: name == "left" ? 480 : 1056, y: 995))
            let factor = stage == 2 ? 0.78 : (stage == 3 ? 0.72 : wingScale4)
            mount.transform = CATransform3DMakeScale(factor, factor, 1)
        }
        let sway = layer(mount, anchor: pivot)
        let wing = layer(sway, anchor: pivot)
        rotate(wing, clockwise: max(angle, -3) * sign)
        if stage < 3 && !adjusted {
            let shadow = layer(wing, anchor: imageCenter, image: original("wing_\(name)_shadow", stage: stage))
            shadow.opacity = Float(max(0, 1 - abs(angle) / 18))
        }
        let art = layer(wing, anchor: adjusted ? pivot : imageCenter, image: stage >= 3 ? newPart("wing_\(name)", stage: stage) : original("wing_\(name)", stage: stage))
        let amount = min(max(angle, 0), 60) / 60
        art.setValue(1 - 0.1 * amount, forKeyPath: "transform.scale.y")
        art.setValue(1 + 0.04 * amount, forKeyPath: "transform.scale.x")
    }
    }
    if stage >= 2 { wings() }
    _ = layer(torso, anchor: imageCenter, image: original("body"))
    if !(stage >= 2) { wings() }
    let face = layer(torso, anchor: imageCenter)
    _ = layer(face, anchor: CGPoint(x: 769.2, y: 846.75), image: original("eyes"))
    if stage < 3 { crest() }
    CATransaction.commit()
    root.render(in: ctx)
    return ctx.makeImage()!
}
func label(_ string: String, in ctx: CGContext, at point: CGPoint, color: NSColor, size: CGFloat = 15) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    string.draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color])
    NSGraphicsContext.restoreGraphicsState()
}
// Package-local focused evidence: preserve per-layer app rasterization, adding canvas headroom only.
for part in ["crest", "tail_left", "tail_right", "wing_left", "wing_right"] {
    for stage in [3, 4] { _ = newPart(part, stage: stage) }
}
let focused = poses.filter { ["neutral", "crest-minus12", "crest-plus12", "jump", "landing"].contains($0.name) }
for (mode, bg) in backgrounds {
    for stage in [3, 4] {
        for pose in focused {
            write(render(stage: stage, pose: pose, bg: bg), "native/\(mode)-stage\(stage)-\(pose.name).png")
            for size: CGFloat in [64, 220] {
                for scale: CGFloat in [1, 3] {
                    write(render(stage: stage, pose: pose, bg: bg, size: size, scale: scale),
                          "tiles/\(mode)-stage\(stage)-\(pose.name)-\(Int(size))pt-\(Int(scale))x.png")
                }
            }
        }
    }
}
try "Focused crest comparison; original layer assets/transforms/crop/downsample. Jump canvas gets512 native pixels of headroom, scaled proportionally at display size. Native composites use full1536 source, never resized for comparison. This is static evidence; no animation/easing/runtime claims.\n".write(to: output.appendingPathComponent("METHOD.txt"), atomically: true, encoding: .utf8)
print("Rendered to \(output.path)")
