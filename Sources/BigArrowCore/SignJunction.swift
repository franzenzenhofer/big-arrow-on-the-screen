import CoreGraphics

/// The sign's outline as the arrow sees it: its rect and its corner radius.
public struct SignOutline: Equatable, Sendable {
    public let rect: CGRect
    public let cornerRadius: CGFloat

    public init(rect: CGRect, cornerRadius: CGFloat) {
        self.rect = rect
        self.cornerRadius = cornerRadius
    }
}

/// Where the shaft leaves the sign: a point on a straight part of the sign's edge, the edge's
/// outward normal, and how wide the flare may be there. The flare never reaches into a rounded
/// corner, because a flare corner outside the rounded outline shows as a jagged notch.
public struct SignJunction: Equatable, Sendable {
    public let point: CGPoint
    public let normal: CGPoint
    public let halfWidth: CGFloat

    /// A straight part shorter than this many strokes (half length) is too short for a flare,
    /// e.g. the round end of a pill; the junction moves to the long top or bottom edge.
    static let minimumHalfFactor: CGFloat = 0.6
    /// Keeps the flare this far from where the rounded corner starts.
    static let cornerClearance: CGFloat = 2

    struct Edge {
        let normal: CGPoint
        /// The point on this edge at `along`, the coordinate along the edge.
        let point: (CGFloat) -> CGPoint
        let straight: ClosedRange<CGFloat>
        let exit: CGFloat
    }

    public static func make(sign: SignOutline, toward tip: CGPoint, stroke: CGFloat, preferredHalf: CGFloat) -> SignJunction {
        let edges = Self.edges(sign, toward: tip)
        let usable = edges.first { ($0.straight.upperBound - $0.straight.lowerBound) / 2 >= stroke * minimumHalfFactor }
        let edge = usable ?? edges[edges.count - 1]
        let halfLength = (edge.straight.upperBound - edge.straight.lowerBound) / 2
        let half = max(min(preferredHalf, halfLength), 0)
        let along = min(max(edge.exit, edge.straight.lowerBound + half), edge.straight.upperBound - half)
        return SignJunction(point: edge.point(along), normal: edge.normal, halfWidth: half)
    }

    /// The edge the ray from the centre to the tip leaves through, then the long edge facing the tip.
    static func edges(_ sign: SignOutline, toward tip: CGPoint) -> [Edge] {
        let rect = sign.rect
        let inset = sign.cornerRadius + cornerClearance
        let horizontal = (rect.minX + inset)...max(rect.maxX - inset, rect.minX + inset)
        let vertical = (rect.minY + inset)...max(rect.maxY - inset, rect.minY + inset)
        let exit = exitPoint(rect, toward: tip)
        let top = Edge(normal: CGPoint(x: 0, y: -1), point: { CGPoint(x: $0, y: rect.minY) }, straight: horizontal, exit: exit.x)
        let bottom = Edge(normal: CGPoint(x: 0, y: 1), point: { CGPoint(x: $0, y: rect.maxY) }, straight: horizontal, exit: exit.x)
        let left = Edge(normal: CGPoint(x: -1, y: 0), point: { CGPoint(x: rect.minX, y: $0) }, straight: vertical, exit: exit.y)
        let right = Edge(normal: CGPoint(x: 1, y: 0), point: { CGPoint(x: rect.maxX, y: $0) }, straight: vertical, exit: exit.y)
        let longEdge = tip.y < rect.midY ? top : bottom
        let distances: [(CGFloat, Edge)] = [
            (abs(exit.y - rect.minY), top), (abs(exit.y - rect.maxY), bottom),
            (abs(exit.x - rect.minX), left), (abs(exit.x - rect.maxX), right)
        ]
        var crossed = distances[0]
        for candidate in distances.dropFirst() where candidate.0 < crossed.0 { crossed = candidate }
        return [crossed.1, longEdge]
    }

    /// Where the ray from the centre to the tip leaves the rect.
    static func exitPoint(_ rect: CGRect, toward tip: CGPoint) -> CGPoint {
        let center = rect.center
        let delta = tip - center
        let scaleX = delta.x == 0 ? CGFloat.infinity : (rect.width / 2) / abs(delta.x)
        let scaleY = delta.y == 0 ? CGFloat.infinity : (rect.height / 2) / abs(delta.y)
        return center + delta * min(scaleX, scaleY, 1)
    }
}
