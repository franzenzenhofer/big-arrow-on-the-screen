import CoreGraphics

/// `--shape spiral`: the shaft leaves the sign, runs once around it on a loop that widens as it
/// goes, so the loop never touches itself, and then curves to the target. The loop turns the way
/// that ends heading towards the target, so the last leg sweeps in instead of doubling back.
public enum Spiral {
    /// Points along the loop; the shaft is drawn as a polyline with round joins.
    static let loopSamples = 96
    static let legSamples = 24
    /// Distance from the sign to the loop where it starts, in strokes.
    static let gapFactor: CGFloat = 2.2
    /// How much wider the loop is when it comes back round, in strokes: more than the shaft's
    /// full width (stroke plus borders), so the end of the loop clears its start.
    static let growthFactor: CGFloat = 2.8
    /// The last stretch runs straight into the head, in head lengths.
    static let runIn: CGFloat = 1.2
    /// The leg to the target starts along the loop's tangent for this share of its length.
    static let legTangent: CGFloat = 0.45

    public struct Request: Sendable {
        public let sign: CGRect
        public let junction: SignJunction
        public let tip: CGPoint
        public let metrics: ArrowMetrics
        public let bounds: CGRect

        public init(sign: CGRect, junction: SignJunction, tip: CGPoint, metrics: ArrowMetrics, bounds: CGRect) {
            (self.sign, self.junction, self.tip, self.metrics, self.bounds) = (sign, junction, tip, metrics, bounds)
        }
    }

    /// The loop and the leg to the target as polyline joints, and the point the head points from.
    public static func route(_ request: Request) -> (control: CGPoint, joints: [CGPoint]) {
        let loops = [CGFloat(1), -1].map { loopPoints(request, turn: $0) }
        let loop = loops.max { heading($0, to: request.tip) < heading($1, to: request.tip) } ?? []
        let end = request.tip - (request.tip - (loop.last ?? request.tip)).normalized * (request.metrics.headLength * runIn)
        let leg = legPoints(loop: loop, end: end)
        let joints = (loop + leg).map { clamp($0, into: request.bounds) }
        return (joints.last ?? end, joints)
    }

    /// Room the loop needs on each side of a sign of `size`, so placement keeps the whole loop
    /// on screen and clear of the target: the widest loop plus half a shaft and its border.
    public static func padding(around size: CGSize, metrics: ArrowMetrics) -> CGSize {
        let extra = metrics.stroke * (gapFactor + growthFactor) + metrics.stroke / 2 + borderAllowance
        return CGSize(width: size.width / 2 * (2.squareRoot() - 1) + extra, height: size.height / 2 * (2.squareRoot() - 1) + extra)
    }

    /// The widest border drawn around the shaft (white border plus black edge), in points.
    static let borderAllowance: CGFloat = 6

    /// One turn around the sign's centre (1: clockwise on screen, -1: anticlockwise), starting
    /// where the shaft leaves the sign.
    static func loopPoints(_ request: Request, turn: CGFloat) -> [CGPoint] {
        let center = CGPoint(x: request.sign.midX, y: request.sign.midY)
        let gap = request.metrics.stroke * gapFactor
        let growth = request.metrics.stroke * growthFactor
        // The smallest ellipse around a rectangle has semi-axes of √2 times its half sides.
        let radii = CGSize(width: request.sign.width / 2 * 2.squareRoot() + gap, height: request.sign.height / 2 * 2.squareRoot() + gap)
        let offset = request.junction.point - center
        let start = atan2(offset.y / radii.height, offset.x / radii.width)
        return (0...loopSamples).map { index in
            let share = CGFloat(index) / CGFloat(loopSamples)
            let angle = start + turn * 2 * .pi * share
            let grown = growth * share
            return center + CGPoint(x: (radii.width + grown) * cos(angle), y: (radii.height + grown) * sin(angle))
        }
    }

    /// How well the loop's last step points at the target: 1 straight at it, -1 away from it.
    static func heading(_ loop: [CGPoint], to tip: CGPoint) -> CGFloat {
        guard loop.count >= 2, let exit = loop.last else { return -1 }
        return (exit - loop[loop.count - 2]).normalized.dot((tip - exit).normalized)
    }

    /// From the loop's end, on along its tangent, then bending into the straight run to the head.
    static func legPoints(loop: [CGPoint], end: CGPoint) -> [CGPoint] {
        guard loop.count >= 2, let exit = loop.last else { return [end] }
        let tangent = (exit - loop[loop.count - 2]).normalized
        let control = exit + tangent * (exit.distance(to: end) * legTangent)
        let curve = QuadCurve(start: exit, control: control, end: end)
        return (1...legSamples).map { curve.point(CGFloat($0) / CGFloat(legSamples)) }
    }

    /// Keeps a point of the loop on the display when the sign sits close to its edge.
    static func clamp(_ point: CGPoint, into bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
    }
}
