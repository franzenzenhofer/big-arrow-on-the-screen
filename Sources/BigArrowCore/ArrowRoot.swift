import CoreGraphics

/// The flared root where the shaft grows out of the sign, like a speech-bubble tail: two cubic
/// flanks leave the sign along its edge and run into the shaft's sides parallel to the shaft,
/// so there is no corner anywhere in the join. Pure.
public struct ArrowRoot: Sendable {
    public let junction: SignJunction
    public let shaft: QuadCurve
    public let stroke: CGFloat

    /// Preferred half width of the root at the sign edge, as a multiple of the stroke.
    public static let baseFactor: CGFloat = 1.8
    /// How far outside the sign the flare has narrowed to the shaft, as a multiple of the stroke.
    public static let flareFactor: CGFloat = 2.6
    /// How far the root reaches into the sign, under the text layer.
    static let depth: CGFloat = 10
    /// The flank corners sit this far inside the sign, so their outline hides under the sign body.
    static let cornerInset: CGFloat = 4
    /// Shafts shorter than this many strokes shrink the flare.
    static let shortShaftFactor: CGFloat = 9

    /// One side of the flare: a cubic from the sign edge into the side of the shaft.
    public struct Flank: Sendable {
        public let onEdge: CGPoint
        public let nearEdge: CGPoint
        public let nearShaft: CGPoint
        public let onShaft: CGPoint
    }

    /// Short arrows get a proportionally smaller flare, so it never runs into the head.
    public var scale: CGFloat {
        min(1, shaft.start.distance(to: shaft.end) / (stroke * Self.shortShaftFactor))
    }

    public var flareLength: CGFloat { stroke * Self.flareFactor * scale }

    /// The shaft parameter where the shaft is `distance` away from the junction (bisection).
    public func parameter(atDistance distance: CGFloat) -> CGFloat {
        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if shaft.point(mid).distance(to: junction.point) < distance { low = mid } else { high = mid }
        }
        return (low + high) / 2
    }

    /// The two sides of the flare, the one on the shaft's left first.
    public var flanks: [Flank] {
        let normal = junction.normal
        let along = normal.perpendicular
        let neckT = parameter(atDistance: flareLength)
        let neck = shaft.point(neckT)
        let tangent = shaft.tangent(neckT)
        let side = tangent.perpendicular
        let orientation: CGFloat = along.dot(side) >= 0 ? 1 : -1
        let base = max(min(junction.halfWidth * scale, junction.halfWidth), stroke / 2)
        let edge = junction.point - normal * Self.cornerInset
        return [orientation, -orientation].map { sign in
            let shaftSide = neck + side * (stroke / 2 * sign * orientation)
            return Flank(
                onEdge: edge + along * (base * sign),
                nearEdge: edge + along * (base * 0.35 * sign),
                nearShaft: shaftSide - tangent * (flareLength * 0.55),
                onShaft: shaftSide
            )
        }
    }

    public var path: CGPath {
        let normal = junction.normal
        let flanks = flanks
        let path = CGMutablePath()
        path.move(to: flanks[0].onEdge - normal * Self.depth)
        path.addLine(to: flanks[0].onEdge)
        path.addCurve(to: flanks[0].onShaft, control1: flanks[0].nearEdge, control2: flanks[0].nearShaft)
        path.addLine(to: flanks[1].onShaft)
        path.addCurve(to: flanks[1].onEdge, control1: flanks[1].nearShaft, control2: flanks[1].nearEdge)
        path.addLine(to: flanks[1].onEdge - normal * Self.depth)
        path.closeSubpath()
        return path
    }
}
