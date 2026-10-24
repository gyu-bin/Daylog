import Testing
import QuartzCore
@testable import Daylog

struct PioVacationAnchorMotionTests {
    @Test func twoSourceAttachmentPointsStayFixedAcrossWholeHingeCycle() {
        for hinge in [PioVacationAnchorMotion.basicDay, .basicNight] {
            for fraction in stride(from: CGFloat(-1), through: 1, by: 0.02) {
                let t = hinge.transform(fraction: fraction)
                for point in [hinge.fixedPoint, hinge.otherPoint] {
                    let projected = hinge.projected(point, through: t)
                    #expect(abs(projected.x - point.x) < 0.000_001)
                    #expect(abs(projected.y - point.y) < 0.000_001)
                }
            }
        }
    }

    @Test func projectedCharacterMovementIsSmallAndExistingPeriodIsPreserved() {
        for (hinge, focus) in [(PioVacationAnchorMotion.basicDay, CGPoint(x: 512, y: 740)),
                               (.basicNight, CGPoint(x: 512, y: 845))] {
            var distances: [CGFloat] = []
            for fraction in [CGFloat(-1), 0, 1] {
                let p = hinge.projected(focus, through: hinge.transform(fraction: fraction))
                distances.append(hypot(p.x - focus.x, p.y - focus.y))
            }
            #expect((distances.max() ?? 0) > 0.5)
            #expect((distances.max() ?? 0) < 12)
            #expect(hinge.animation().duration == 7.6)
        }
    }

    @Test func invalidOrAggressiveRegistrationIsRejected() {
        #expect(PioVacationAnchorMotion(fixedPoint: .zero, otherPoint: .zero) == nil)
        #expect(PioVacationAnchorMotion(fixedPoint: .zero, otherPoint: CGPoint(x: 800, y: 20), maximumShear: 0.3) == nil)
        #expect(PioVacationAnchorMotion(fixedPoint: .zero, otherPoint: CGPoint(x: CGFloat.nan, y: 20)) == nil)
    }

    @Test func everyNativeTransformIsPlanarAndPreservesArea() {
        for hinge in [PioVacationAnchorMotion.basicDay, .basicNight] {
            for fraction in stride(from: CGFloat(-1), through: 1, by: 0.02) {
                let transform = hinge.transform(fraction: fraction)
                #expect(CATransform3DIsAffine(transform))
                let t = CATransform3DGetAffineTransform(transform)
                #expect(abs(t.a * t.d - t.b * t.c - 1) < 0.000_001)
            }
        }
    }
}
