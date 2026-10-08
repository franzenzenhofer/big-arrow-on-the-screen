import BigArrowCore
import CoreGraphics
import Testing

@Suite("ArrowGeometry")
struct ArrowGeometryTests {
    let display = TestDisplays.builtIn
    let signSize = CGSize(width: 421, height: 84)

    func layout(at point: CGPoint, from direction: ApproachDirection?, size: ArrowSize = .medium) -> OverlayLayout {
        OverlayLayout.plan(OverlayLayout.Request(
            target: .point(point), display: display, signSize: signSize,
            style: .arrow, size: size, forced: direction
        ))
    }

    @Test("The arrowhead tip is the target point within 0.5 pt", arguments: ApproachDirection.allCases)
    func tipIsTarget(direction: ApproachDirection) {
        let target = CGPoint(x: 756, y: 500)
        let arrow = layout(at: target, from: direction).arrow
        #expect(arrow.tip.distance(to: target) <= 0.5)
        #expect(arrow.headPoints[0].distance(to: target) <= 0.5)
    }

    @Test("The head points along the shaft's end tangent", arguments: ApproachDirection.allCases)
    func headFollowsTangent(direction: ApproachDirection) {
        let arrow = layout(at: CGPoint(x: 756, y: 500), from: direction).arrow
        let tangent = (arrow.shaftEnd - arrow.control).normalized
        let headAxis = (arrow.tip - arrow.headPoints[2]).normalized
        #expect(tangent.dot(arrow.direction) > 0.9999)
        #expect(headAxis.dot(arrow.direction) > 0.9999)
    }

    @Test("Shaft, head and sign stay inside the display for all 8 approach directions", arguments: ApproachDirection.allCases)
    func staysInside(direction: ApproachDirection) {
        let planned = layout(at: CGPoint(x: 756, y: 500), from: direction)
        let metrics = ArrowSize.medium.metrics
        let shaft = planned.arrow.shaftPath.boundingBoxOfPath.insetBy(dx: -metrics.stroke / 2, dy: -metrics.stroke / 2)
        let bounds = display.localBounds
        #expect(bounds.contains(shaft))
        #expect(bounds.contains(planned.arrow.headPath.boundingBoxOfPath))
        #expect(bounds.contains(planned.signRect))
        #expect(planned.direction == direction)
    }

    @Test("Stroke, head and font grow with the size")
    func sizesScale() {
        let metrics = ArrowSize.allCases.map(\.metrics)
        #expect(metrics.map(\.stroke) == metrics.map(\.stroke).sorted())
        #expect(metrics.map(\.headLength) == metrics.map(\.headLength).sorted())
        #expect(metrics.map(\.fontSize) == metrics.map(\.fontSize).sorted())
        #expect(metrics.allSatisfy { $0.fontSize >= ArrowMetrics.minimumFontSize })
    }

    @Test("Rect targets get a box and the tip sits just outside the edge midpoint facing the sign")
    func rectTip() {
        let rect = CGRect(x: 600, y: 400, width: 200, height: 80)
        let planned = OverlayLayout.plan(OverlayLayout.Request(
            target: .rect(rect), display: display, signSize: signSize, style: .arrow, size: .medium, forced: .bottom
        ))
        guard case .box(let box) = planned.mark else {
            Issue.record("expected a box mark")
            return
        }
        #expect(box == rect.insetBy(dx: -OverlayLayout.boxPadding, dy: -OverlayLayout.boxPadding))
        #expect(planned.arrow.tip.distance(to: CGPoint(x: box.midX, y: box.maxY + OverlayLayout.markGap)) < 0.5)
    }
}

/// The join between sign and shaft must be smooth: no kink where the flare meets the shaft,
/// the flare leaves the sign along its edge, and never inside a rounded corner.
@Suite("Arrow root")
struct ArrowRootTests {
    let display = TestDisplays.builtIn

    func plan(from direction: ApproachDirection, size: ArrowSize, corners: SignCorners = .round) -> OverlayLayout {
        OverlayLayout.plan(OverlayLayout.Request(
            target: .point(CGPoint(x: 756, y: 500)), display: display, signSize: CGSize(width: 421, height: 84),
            style: .arrow, size: size, forced: direction, corners: corners
        ))
    }

    static let cases = ApproachDirection.allCases.flatMap { direction in ArrowSize.allCases.map { (direction, $0) } }

    @Test("The flare ends exactly on the shaft's sides, parallel to the shaft", arguments: cases)
    func flareMeetsShaftSmoothly(direction: ApproachDirection, size: ArrowSize) {
        let root = plan(from: direction, size: size).arrow.root
        let t = root.parameter(atDistance: root.flareLength)
        let neck = root.shaft.point(t)
        let side = root.shaft.tangent(t).perpendicular
        let expected = [neck + side * (root.stroke / 2), neck - side * (root.stroke / 2)]
        for flank in root.flanks {
            #expect(expected.contains { $0.distance(to: flank.onShaft) < 0.01 })
            let incoming = (flank.onShaft - flank.nearShaft).normalized
            #expect(incoming.dot(root.shaft.tangent(t)) > 0.9999, "kink where the flare meets the shaft")
        }
    }

    @Test("The flare leaves the sign along the sign's edge", arguments: cases)
    func flareLeavesAlongEdge(direction: ApproachDirection, size: ArrowSize) {
        let root = plan(from: direction, size: size).arrow.root
        let along = root.junction.normal.perpendicular
        for flank in root.flanks {
            let outgoing = (flank.nearEdge - flank.onEdge).normalized
            #expect(abs(outgoing.dot(along)) > 0.9999, "the flare must start tangent to the sign edge")
        }
    }

    @Test("The flare stays on a straight part of the edge, clear of rounded corners", arguments: cases)
    func flareAvoidsRoundedCorners(direction: ApproachDirection, size: ArrowSize) {
        let layout = plan(from: direction, size: size)
        let sign = layout.signRect
        let radius = SignCorners.round.radius(height: sign.height)
        let straightX = (sign.minX + radius)...(sign.maxX - radius)
        let straightY = (sign.minY + radius)...(sign.maxY - radius)
        for flank in layout.arrow.root.flanks {
            #expect(sign.contains(flank.onEdge))
            #expect(straightX.contains(flank.onEdge.x) || straightY.contains(flank.onEdge.y), "flare corner in a rounded corner")
        }
    }

    @Test("The shaft starts inside the sign and first heads away from it", arguments: cases)
    func shaftLeavesSign(direction: ApproachDirection, size: ArrowSize) {
        let layout = plan(from: direction, size: size)
        let root = layout.arrow.root
        #expect(layout.signRect.contains(layout.arrow.tail))
        #expect(root.shaft.tangent(0).dot(root.junction.normal) > 0)
    }

    @Test("Sharp corners allow a junction anywhere on the edge")
    func sharpCorners() {
        let layout = plan(from: .left, size: .small, corners: .sharp)
        #expect(layout.arrow.root.junction.normal == CGPoint(x: 1, y: 0))
    }
}

@Suite("Arrow shapes")
struct ArrowShapeTests {
    let display = TestDisplays.builtIn
    static let cases = ArrowShape.allCases.flatMap { shape in ApproachDirection.allCases.map { (shape, $0) } }

    func plan(_ shape: ArrowShape, from direction: ApproachDirection) -> OverlayLayout {
        OverlayLayout.plan(OverlayLayout.Request(
            target: .point(CGPoint(x: 756, y: 500)), display: display, signSize: CGSize(width: 421, height: 84),
            style: .arrow, size: .medium, forced: direction, shape: shape
        ))
    }

    @Test("Every shape hits the target, points the head along its last stretch and stays on screen", arguments: cases)
    func shapes(shape: ArrowShape, direction: ApproachDirection) {
        let arrow = plan(shape, from: direction).arrow
        #expect(arrow.tip.distance(to: CGPoint(x: 756, y: 500)) <= 0.5)
        #expect((arrow.shaftEnd - arrow.control).normalized.dot(arrow.direction) > 0.9999)
        #expect(display.localBounds.contains(arrow.shaftPath.boundingBoxOfPath))
    }

    @Test("A straight shaft is a straight line from the sign to the head", arguments: ApproachDirection.allCases)
    func straight(direction: ApproachDirection) {
        let arrow = plan(.straight, from: direction).arrow
        let line = (arrow.shaftEnd - arrow.tail).normalized
        #expect((arrow.control - arrow.tail).normalized.dot(line) > 0.9999)
        #expect(arrow.direction.dot(line) > 0.9999)
    }

    @Test("A zigzag leaves the sign straight out, then swings, then runs straight into the head", arguments: ApproachDirection.allCases)
    func zigzag(direction: ApproachDirection) throws {
        let arrow = plan(.zigzag, from: direction).arrow
        guard case .polyline(let points) = arrow.shaft else {
            Issue.record("a zigzag must be a polyline")
            return
        }
        #expect(points.count >= 5)
        let leadOut = (points[1] - points[0]).normalized
        #expect(leadOut.dot(arrow.root.junction.normal) > 0.999)
        let lastLeg = (points[points.count - 1] - points[points.count - 2]).normalized
        #expect(lastLeg.dot(arrow.direction) > 0.9999)
    }

    @Test("Shapes parse by name and reject anything else")
    func parsing() throws {
        #expect(try ArrowShape.parse("ZigZag") == .zigzag)
        #expect(throws: BigArrowError.self) { try ArrowShape.parse("spiral") }
    }
}
