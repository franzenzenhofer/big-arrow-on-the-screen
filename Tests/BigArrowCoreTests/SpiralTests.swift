import BigArrowCore
import CoreGraphics
import Testing

@Suite("Spiral")
struct SpiralTests {
    let display = TestDisplays.builtIn

    func plan(_ shape: ArrowShape, from direction: ApproachDirection) -> OverlayLayout {
        OverlayLayout.plan(OverlayLayout.Request(
            target: .point(CGPoint(x: 756, y: 500)), display: display, signSize: CGSize(width: 421, height: 84),
            style: .arrow, size: .medium, forced: direction, shape: shape
        ))
    }

    @Test("A spiral loops once around the sign without touching it or itself, then hits the target", arguments: ApproachDirection.allCases)
    func spiral(direction: ApproachDirection) throws {
        let planned = plan(.spiral, from: direction)
        let arrow = planned.arrow
        guard case .polyline(let points) = arrow.shaft else {
            Issue.record("a spiral must be a polyline")
            return
        }
        // points[0] is the tail inside the sign; the loop's 97 samples (entry curve included) follow it.
        let loop = Array(points.dropFirst().prefix(97))
        let stroke = ArrowSize.medium.metrics.stroke
        let clear = planned.signRect.insetBy(dx: -stroke, dy: -stroke)
        // The first 8 points curve out of the sign into the loop; from there on it keeps clear.
        #expect(loop.dropFirst(8).allSatisfy { !clear.contains($0) }, "the loop runs over the sign")
        let center = CGPoint(x: planned.signRect.midX, y: planned.signRect.midY)
        let angles = loop.map { atan2($0.y - center.y, $0.x - center.x) }
        let turned = zip(angles, angles.dropFirst()).reduce(CGFloat(0)) { sum, pair in
            var step = pair.1 - pair.0
            if step > .pi { step -= 2 * .pi }
            if step < -.pi { step += 2 * .pi }
            return sum + step
        }
        // The entry curve starts at the sign, so the loop seen from the sign's centre turns a bit less than 360°.
        #expect(abs(turned) > 2 * .pi * 0.85, "turned \(turned) rad")
        let start = try #require(loop.first)
        let end = try #require(loop.last)
        #expect(start.distance(to: end) >= stroke * 2.5, "the loop's end must clear its start")
        #expect(arrow.tip.distance(to: CGPoint(x: 756, y: 500)) <= 0.5)
    }
}
