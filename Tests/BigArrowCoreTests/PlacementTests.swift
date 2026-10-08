import BigArrowCore
import CoreGraphics
import Testing

@Suite("Placement")
struct PlacementTests {
    static let display = TestDisplays.builtIn
    static let signSize = CGSize(width: 421, height: 84)

    /// Corners and edge midpoints of the built-in display, 4 pt inside.
    static let hardTargets: [CGPoint] = {
        let bounds = display.localBounds.insetBy(dx: 4, dy: 4)
        let xs = [bounds.minX, bounds.midX, bounds.maxX]
        let ys = [bounds.minY, bounds.midY, bounds.maxY]
        return xs.flatMap { x in ys.map { CGPoint(x: x, y: $0) } }.filter { $0 != bounds.center }
    }()

    func place(_ target: CGPoint, forced: ApproachDirection? = nil) -> Placement.Result {
        Placement.place(
            sign: Self.signSize, around: CGRect(origin: target, size: .zero),
            in: Self.display.localVisibleBounds, reach: ArrowSize.medium.metrics.reach, forced: forced
        )
    }

    @Test("Targets in every corner and edge midpoint get a sign fully on screen, clear of the 120 pt zone", arguments: hardTargets)
    func cornersAndEdges(target: CGPoint) {
        let result = place(target)
        let zone = CGRect(x: target.x - 60, y: target.y - 60, width: 120, height: 120)
        #expect(Self.display.localBounds.contains(result.signRect))
        #expect(Self.display.localVisibleBounds.contains(result.signRect))
        #expect(!result.signRect.intersects(zone))
    }

    @Test("Equal inputs give equal outputs")
    func deterministic() {
        let target = CGPoint(x: 300, y: 300)
        #expect(place(target) == place(target))
    }

    @Test("A forced side is honoured when the sign fits there")
    func forcedSide() {
        #expect(place(CGPoint(x: 756, y: 500), forced: .right).direction == .right)
        #expect(place(CGPoint(x: 756, y: 500), forced: .topLeft).direction == .topLeft)
    }

    @Test("A forced side where the sign does not fit falls back to a side that keeps the target visible")
    func forcedSideNeverCoversTarget() {
        let target = CGPoint(x: Self.display.localBounds.maxX - 30, y: 500)
        let result = place(target, forced: .right)
        let zone = CGRect(x: target.x - 60, y: target.y - 60, width: 120, height: 120)
        #expect(result.direction != .right)
        #expect(!result.signRect.intersects(zone))
        #expect(Self.display.localBounds.contains(result.signRect))
    }

    @Test("A second arrow keeps its sign clear of the first arrow's sign")
    func avoidsOtherSigns() {
        let target = CGPoint(x: 756, y: 500)
        let first = place(target)
        let second = Placement.place(
            sign: Self.signSize, around: CGRect(origin: target, size: .zero), in: Self.display.localVisibleBounds,
            reach: ArrowSize.medium.metrics.reach, avoiding: [first.signRect]
        )
        #expect(!second.signRect.intersects(first.signRect.insetBy(dx: -Placement.otherGap, dy: -Placement.otherGap)))
    }

    @Test("A sign that cannot fit anywhere is clamped onto the display instead of leaving it")
    func clampsHugeSign() {
        let result = Placement.place(
            sign: CGSize(width: 1400, height: 800), around: CGRect(x: 756, y: 500, width: 0, height: 0),
            in: Self.display.localVisibleBounds, reach: 170
        )
        #expect(Self.display.localBounds.contains(result.signRect))
    }

    @Test("The keep-out zone grows to cover a large marked rect")
    func keepOutCoversRect() {
        let rect = CGRect(x: 100, y: 100, width: 400, height: 300)
        #expect(Placement.keepOutZone(around: rect).contains(rect))
    }
}
