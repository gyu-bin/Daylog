import QuartzCore
import CoreGraphics

/// Candidate two-point hinge for a complete authored foreground. This changes
/// its projection only; it does not invent hidden rope, hand, or background art.
/// The existing layer anchor must equal `fixedPoint` in source coordinates.
struct PioVacationAnchorMotion {
    let fixedPoint: CGPoint
    let otherPoint: CGPoint
    let maximumDegrees: CGFloat
    let perspectiveDistance: CGFloat

    init?(fixedPoint: CGPoint, otherPoint: CGPoint, maximumDegrees: CGFloat = 6,
          perspectiveDistance: CGFloat = 1800) {
        let values = [fixedPoint.x, fixedPoint.y, otherPoint.x, otherPoint.y,
                      maximumDegrees, perspectiveDistance]
        guard values.allSatisfy(\.isFinite), hypot(otherPoint.x - fixedPoint.x,
            otherPoint.y - fixedPoint.y) > 100, maximumDegrees > 0,
            maximumDegrees <= 6, perspectiveDistance >= 1800 else { return nil }
        self.fixedPoint = fixedPoint; self.otherPoint = otherPoint
        self.maximumDegrees = maximumDegrees; self.perspectiveDistance = perspectiveDistance
    }

    func transform(fraction: CGFloat) -> CATransform3D {
        let dx = otherPoint.x - fixedPoint.x, dy = otherPoint.y - fixedPoint.y
        let length = hypot(dx, dy)
        let angle = max(-1, min(1, fraction)) * maximumDegrees * .pi / 180
        let rotation = CATransform3DMakeRotation(angle, dx / length, dy / length, 0)
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / perspectiveDistance
        return CATransform3DConcat(rotation, perspective)
    }

    func animation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = [CGFloat(0), 1, 0, -1, 0].map { NSValue(caTransform3D: transform(fraction: $0)) }
        animation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
        animation.duration = 7.6; animation.repeatCount = .infinity
        return animation
    }

    /// Source-space projection used to compare both attachment pixels before
    /// and after the exact matrix used by Core Animation, including perspective.
    func projected(_ source: CGPoint, through t: CATransform3D) -> CGPoint {
        let x = source.x - fixedPoint.x, y = source.y - fixedPoint.y
        let w = x * t.m14 + y * t.m24 + t.m44
        return CGPoint(x: fixedPoint.x + (x * t.m11 + y * t.m21 + t.m41) / w,
                       y: fixedPoint.y + (x * t.m12 + y * t.m22 + t.m42) / w)
    }

    // Basic-only diagnostic registrations, measured from the original PNGs.
    // The second point is a visible canvas-edge rope entry, not a hidden knot.
    static let basicDay = PioVacationAnchorMotion(fixedPoint: CGPoint(x: 968, y: 484),
                                                 otherPoint: CGPoint(x: 0, y: 684))!
    static let basicNight = PioVacationAnchorMotion(fixedPoint: CGPoint(x: 68, y: 465),
                                                   otherPoint: CGPoint(x: 1024, y: 820))!
}
