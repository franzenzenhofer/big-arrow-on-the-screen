import CoreGraphics

/// The arrow from the sign to the target: a flared root, a curved shaft and a notched head.
/// Display-local top-left points, no AppKit.
public struct ArrowGeometry: Sendable {
    public let tip: CGPoint
    public let tail: CGPoint
    /// The point the shaft's last stretch comes from: the curve's control point, or the last
    /// zigzag joint. `shaftEnd - control` is the direction the head points.
    public let control: CGPoint
    public let shaft: ShaftLine
    /// Where the shaft stops, hidden inside the head.
    public let shaftEnd: CGPoint
    /// Unit tangent of the shaft at its end, the direction the head points.
    public let direction: CGPoint
    public let headPoints: [CGPoint]
    /// The flared join between sign and shaft.
    public let root: ArrowRoot

    /// How far the shaft starts inside the sign's edge, so it grows out of the sign. The sign's
    /// text is drawn above the arrow, so the part inside the sign never covers a letter.
    public static let tailInset: CGFloat = 12
    /// Bow of the shaft as a share of its length.
    public static let bend: CGFloat = 0.22
    /// The shaft leaves the sign at least this share of its length outwards before it bends,
    /// so it never hooks back across the sign.
    static let minimumLeave: CGFloat = 0.25
    /// The zigzag's straight run into the head, in head lengths.
    static let zigzagRunIn: CGFloat = 1.2
    /// The zigzag's straight lead-out from the sign, in strokes, so it never hugs the sign edge.
    static let zigzagLeadOut: CGFloat = 3.5

    /// Size metrics plus the shaft shape.
    public struct Style: Sendable {
        public let metrics: ArrowMetrics
        public let shape: ArrowShape

        public init(metrics: ArrowMetrics, shape: ArrowShape) {
            self.metrics = metrics
            self.shape = shape
        }
    }

    public init(tip: CGPoint, sign: SignOutline, bounds: CGRect, style: Style) {
        let metrics = style.metrics
        self.tip = tip
        let junction = SignJunction.make(
            sign: sign, toward: tip, stroke: metrics.stroke, preferredHalf: metrics.stroke * ArrowRoot.baseFactor
        )
        let tail = Self.tail(of: junction)
        let (control, joints) = Self.route(style: style, junction: junction, tip: tip, bounds: bounds)
        let direction = (tip - control).normalized
        let base = tip - direction * metrics.headLength
        let side = direction.perpendicular * (metrics.headWidth / 2)
        let shaftEnd = tip - direction * (metrics.headLength * 0.7)
        self.tail = tail
        self.control = control
        self.direction = direction
        self.shaftEnd = shaftEnd
        self.headPoints = [tip, base + side, tip - direction * (metrics.headLength * 0.78), base - side]
        let curve = QuadCurve(start: tail, control: control, end: shaftEnd)
        self.shaft = joints.isEmpty ? .curve(curve) : .polyline([tail] + joints + [shaftEnd])
        let firstLeg = joints.first.map { QuadCurve(start: tail, control: tail + ($0 - tail) * 0.5, end: $0) } ?? curve
        self.root = ArrowRoot(junction: junction, shaft: firstLeg, stroke: metrics.stroke)
    }

    public var shaftPath: CGPath { shaft.path }

    public var headPath: CGPath {
        let path = CGMutablePath()
        path.addLines(between: headPoints)
        path.closeSubpath()
        return path
    }

    static func tail(of junction: SignJunction) -> CGPoint {
        junction.point - junction.normal * tailInset
    }

    /// The shaft's last control point and, for a zigzag, its joints.
    static func route(style: Style, junction: SignJunction, tip: CGPoint, bounds: CGRect) -> (CGPoint, [CGPoint]) {
        let metrics = style.metrics
        let tail = tail(of: junction)
        switch style.shape {
        case .bend:
            let inside = bounds.insetBy(dx: metrics.stroke, dy: metrics.stroke)
            return (controlPoint(tail: tail, tip: tip, leaving: junction.normal, bounds: inside), [])
        case .straight:
            return (tail + (tip - tail) * 0.5, [])
        case .zigzag:
            let leadOut = junction.point + junction.normal * (metrics.stroke * zigzagLeadOut)
            let end = tip - (tip - leadOut).normalized * (metrics.headLength * zigzagRunIn)
            let joints = [leadOut] + Zigzag.joints(tail: leadOut, end: end, leaving: junction.normal, stroke: metrics.stroke) + [end]
            return (end, joints)
        }
    }

    /// Bows the shaft to the side that keeps it furthest from the display edges, makes sure it
    /// first heads away from the sign, and keeps the control point on the display.
    static func controlPoint(tail: CGPoint, tip: CGPoint, leaving normal: CGPoint, bounds: CGRect) -> CGPoint {
        let chord = tip - tail
        let mid = tail + chord * 0.5
        let offset = chord.perpendicular.normalized * (chord.length * bend)
        let candidates = [mid + offset, mid - offset]
        var best = candidates.max { clearance($0, bounds) < clearance($1, bounds) } ?? mid
        let outwards = (best - tail).dot(normal)
        let wanted = chord.length * minimumLeave
        if outwards < wanted { best += normal * (wanted - outwards) }
        return CGPoint(x: min(max(best.x, bounds.minX), bounds.maxX), y: min(max(best.y, bounds.minY), bounds.maxY))
    }

    static func clearance(_ point: CGPoint, _ bounds: CGRect) -> CGFloat {
        min(point.x - bounds.minX, bounds.maxX - point.x, point.y - bounds.minY, bounds.maxY - point.y)
    }
}

/// A quadratic Bezier curve.
public struct QuadCurve: Equatable, Sendable {
    public let start: CGPoint
    public let control: CGPoint
    public let end: CGPoint

    public func point(_ t: CGFloat) -> CGPoint {
        start * ((1 - t) * (1 - t)) + control * (2 * (1 - t) * t) + end * (t * t)
    }

    public func tangent(_ t: CGFloat) -> CGPoint {
        ((control - start) * (2 * (1 - t)) + (end - control) * (2 * t)).normalized
    }
}
