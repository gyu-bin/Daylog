// Standalone offline QA renderer. No application code or asset catalog is changed.
// swiftc -O Tools/pio-rig/validate-stage3.swift -o /tmp/pio-validate-stage3
// /tmp/pio-validate-stage3 <candidate-directory> <output-directory> [repository-root] [--stage3-padding]
import AppKit
import QuartzCore
import ImageIO
import UniformTypeIdentifiers
import Accelerate

let args = CommandLine.arguments
guard args.count >= 3 else { fatalError("Usage: validate-stage3 <candidates> <output> [repo]") }
let candidates = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let repo = URL(fileURLWithPath: args.count > 3 && !args[3].hasPrefix("--") ? args[3] : FileManager.default.currentDirectoryPath)
let paddedStage3 = args.contains("--stage3-padding")
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
func newPart(_ part: String) -> CGImage { load(candidates.appendingPathComponent("pio_stage3_\(part).png")) }
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
    let padding: CGFloat = !native && paddedStage3 && stage == 3 ? max(2, ceil(size! * 27 / fitted)) : 2
    let side = native ? canvas : size! + padding * 2
    // Native jump keeps full 1536-pixel source detail and reserves headroom rather than clipping flight.
    let headroom: CGFloat = native && pose.bob > 0 ? 512 : 0
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
        let l = layer(torso, anchor: CGPoint(x: 745.05, y: 588), image: stage == 3 ? newPart("crest") : original("crest"))
        rotate(l, clockwise: pose.crest)
    }
    if stage == 3 {
        crest()
        for name in ["tail_left", "tail_right"] { _ = layer(torso, anchor: imageCenter, image: newPart(name)) }
    }
    _ = layer(torso, anchor: imageCenter, image: original("body"))
    for (name, pivot, angle, sign) in [("left", CGPoint(x: 481.95, y: 940.05), pose.left, CGFloat(1)),
                                       ("right", CGPoint(x: 1054.05, y: 940.05), pose.right, CGFloat(-1))] {
        let sway = layer(torso, anchor: pivot)
        let wing = layer(sway, anchor: pivot)
        rotate(wing, clockwise: max(angle, -3) * sign)
        if stage < 3 {
            let shadow = layer(wing, anchor: imageCenter, image: original("wing_\(name)_shadow", stage: stage))
            shadow.opacity = Float(max(0, 1 - abs(angle) / 18))
        }
        let art = layer(wing, anchor: imageCenter, image: stage == 3 ? newPart("wing_\(name)") : original("wing_\(name)", stage: stage))
        let amount = min(max(angle, 0), 60) / 60
        art.setValue(1 - 0.1 * amount, forKeyPath: "transform.scale.y")
        art.setValue(1 + 0.04 * amount, forKeyPath: "transform.scale.x")
    }
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
// Fail immediately for missing candidate files rather than silently publishing partial composites.
for part in ["crest", "tail_left", "tail_right", "wing_left", "wing_right"] { _ = newPart(part) }
for (mode, bg) in backgrounds {
    for pose in poses {
        let result = render(stage: 3, pose: pose, bg: bg)
        write(result, "native/\(mode)-stage3-\(pose.name).png")
        if pose.name != "jump" {
            for (joint, rect) in [("crest", CGRect(x: 410, y: 230, width: 680, height: 480)),
                                  ("shoulder-left", CGRect(x: 210, y: 735, width: 410, height: 425)),
                                  ("shoulder-right", CGRect(x: 915, y: 735, width: 410, height: 425)),
                                  ("tail-left", CGRect(x: 150, y: 940, width: 520, height: 440)),
                                  ("tail-right", CGRect(x: 865, y: 940, width: 520, height: 440))] {
                if let crop = result.cropping(to: rect) { write(crop, "joints/\(mode)-\(pose.name)-\(joint).png") }
            }
        }
    }
    for stage in [1, 2] { write(render(stage: stage, pose: poses[0], bg: bg), "native/\(mode)-stage\(stage)-neutral.png") }
    for scale: CGFloat in [1, 2] {
        let width = 840, height = 620
        let board = context(Int(CGFloat(width) * scale), Int(CGFloat(height) * scale))
        board.scaleBy(x: scale, y: scale)
        board.setFillColor(bg.cgColor); board.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let textColor: NSColor = mode == "dark" ? .white : .black
        label("Same body scale / shared app crop / @\(Int(scale))x", in: board, at: CGPoint(x: 20, y: 590), color: textColor)
        for (row, size) in [CGFloat(48), 64, 76, 220].enumerated() {
            let baseline: CGFloat = [470, 360, 245, 0][row]
            label("\(Int(size))pt", in: board, at: CGPoint(x: 10, y: baseline + 14), color: textColor)
            for stage in 1...3 {
                let x = CGFloat(100 + (stage - 1) * 245)
                let image = render(stage: stage, pose: poses[0], bg: bg, size: size, scale: scale)
                board.draw(image, in: CGRect(x: x, y: baseline, width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale))
                if row == 0 { label("Stage \(stage)", in: board, at: CGPoint(x: x, y: 550), color: textColor) }
                write(image, "sizes/\(mode)-stage\(stage)-\(Int(size))pt-\(Int(scale))x.png")
            }
        }
        write(board.makeImage()!, "comparison-\(mode)-\(Int(scale))x.png")
    }
}
let notes = """
Static Stage 3 validation (generated by validate-stage3.swift)

Stage 3 viewport padding correction: \(paddedStage3 ? "ENABLED — max(2, ceil(size * 27 / 1228.5)) pt; 5pt at220, 2pt at48/64/76" : "DISABLED — app baseline 2pt"). Stage1/2 remain2pt. Source body scale and crop center are unchanged.

Uses original app body/eyes/feet, original Stage 1/2 wings and crest for comparisons, and five candidate Stage 3 files. Every input must be 1536x1536. Uses real CALayer hierarchy and render(in:), app shoulder/crest/hip/foot pivots, clockwise signs, wing perspective image scaling about shared crop center, and shadow fade for Stages 1/2. Stage 3 has no old wing shadows. Proposed Stage 3 rear crest and tails live under torso before body; feet remain separate children of breather. This does not change app code.

Native composites preserve source pixel scale. Native jump has 512px extra headroom (1536x2048) so a full-height hop remains visible. Other native images are 1536x1536. Joint crops are native pixels, not enlarged.

Small previews duplicate the app's shared 1228.5px fitted crop, footBottom=(755.25,1354.5), 2pt padding and vImage high-quality per-layer downsampling. All stages retain identical body scale. @1x and @2x files state actual logical size; no per-stage fit-to-content. Cropping in these previews exposes existing renderer clipping if candidate geometry exceeds its limits.

Static stress poses: wings 48 degrees, wave right 62 degrees, crest +/-12 degrees. Jump/landing sample bigHop tracks at t=.32/.56 using linear keyframe interpolation; this includes additional landing crest rotation 16.625 degrees. Continuous idle sway, temporal easing, blinking, walking, runtime memory/CPU and Reduce Motion are not validated by static exports. Static files are evidence for visual inspection, not a PASS claim or runtime proof.

Source references: PioTrial.swift:40-62; SaessagiIdleView.swift:335-347,455-516,714-747; SaessagiRenderer.swift:64-104; SaessagiWalk.swift:659-700.
"""
try notes.write(to: output.appendingPathComponent("VALIDATION.txt"), atomically: true, encoding: .utf8)
print("Rendered validation to \(output.path)")
