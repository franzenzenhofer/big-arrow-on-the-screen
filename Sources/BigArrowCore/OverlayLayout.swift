import CoreGraphics

/// The mark drawn on the target itself, besides the arrow.
public enum TargetMark: Equatable, Sendable {
    case none
    case box(CGRect)
    case ring(center: CGPoint, radius: CGFloat)

    /// The area the mark occupies, used as the zone the sign keeps clear of.
    var area: CGRect? {
        switch self {
        case .none: nil
        case .box(let rect): rect
        case .ring(let center, let radius):
            CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        }
    }
}

/// Everything the overlay draws on one display, in display-local top-left points.
public struct OverlayLayout: Sendable {
    public let display: Display
    public let mark: TargetMark
    public let signRect: CGRect
    public let direction: ApproachDirection
    public let arrow: ArrowGeometry
    public let size: ArrowSize

    public struct Request: Sendable {
        public let target: TargetShape
        public let display: Display
        public let signSize: CGSize
        public let style: ArrowStyle
        public let size: ArrowSize
        public let forced: ApproachDirection?
        public let corners: SignCorners

        public init(
            target: TargetShape, display: Display, signSize: CGSize,
            style: ArrowStyle, size: ArrowSize, forced: ApproachDirection?, corners: SignCorners = .round
        ) {
            self.corners = corners
            self.target = target
            self.display = display
            self.signSize = signSize
            self.style = style
            self.size = size
            self.forced = forced
        }
    }

    /// Padding between a highlighted rect and its box.
    public static let boxPadding: CGFloat = 8
    /// Gap between a box or ring and the arrow tip.
    public static let markGap: CGFloat = 6

    public static func plan(_ request: Request) -> OverlayLayout {
        let display = request.display
        let local = localShape(request.target, display: display)
        let mark = mark(for: local, style: request.style)
        let marked = mark.area ?? CGRect(origin: local.anchor, size: .zero)
        let metrics = request.size.metrics
        let placement = Placement.place(
            sign: request.signSize, around: marked, in: display.localVisibleBounds,
            reach: metrics.reach, forced: request.forced
        )
        let tip = tipPoint(local: local, mark: mark, toward: placement.signRect.center)
        let outline = SignOutline(
            rect: placement.signRect, cornerRadius: request.corners.radius(height: placement.signRect.height)
        )
        let arrow = ArrowGeometry(tip: tip, sign: outline, bounds: display.localBounds, metrics: metrics)
        return OverlayLayout(
            display: display, mark: mark, signRect: placement.signRect,
            direction: placement.direction, arrow: arrow, size: request.size
        )
    }

    static func localShape(_ target: TargetShape, display: Display) -> TargetShape {
        switch target {
        case .point(let point): .point(display.local(point))
        case .rect(let rect): .rect(display.local(rect))
        }
    }

    static func mark(for target: TargetShape, style: ArrowStyle) -> TargetMark {
        switch (style, target) {
        case (.ring, _):
            let radius = max(36, (target.rect.map { hypot($0.width, $0.height) / 2 } ?? 0) + 12)
            return .ring(center: target.anchor, radius: radius)
        case (_, .rect(let rect)):
            return .box(rect.insetBy(dx: -boxPadding, dy: -boxPadding))
        case (.box, .point(let point)):
            return .box(CGRect(x: point.x - 36, y: point.y - 36, width: 72, height: 72))
        case (.arrow, .point):
            return .none
        }
    }

    /// Point targets are hit exactly. Boxes are hit at the edge midpoint nearest the sign,
    /// rings at the point facing the sign.
    static func tipPoint(local: TargetShape, mark: TargetMark, toward sign: CGPoint) -> CGPoint {
        switch mark {
        case .none:
            return local.anchor
        case .ring(let center, let radius):
            return center + (sign - center).normalized * (radius + markGap)
        case .box(let rect):
            let midpoints = [
                (CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: 0, y: -1)),
                (CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: 0, y: 1)),
                (CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: -1, y: 0)),
                (CGPoint(x: rect.maxX, y: rect.midY), CGPoint(x: 1, y: 0))
            ]
            var nearest = midpoints[0]
            for candidate in midpoints.dropFirst() where candidate.0.distance(to: sign) < nearest.0.distance(to: sign) {
                nearest = candidate
            }
            return nearest.0 + nearest.1 * markGap
        }
    }
}
