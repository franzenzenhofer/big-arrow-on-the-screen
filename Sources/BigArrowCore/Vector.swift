import CoreGraphics

/// Small vector helpers on CGPoint, used by the pure geometry code.
extension CGPoint {
    public static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }

    public static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    public var length: CGFloat { (x * x + y * y).squareRoot() }

    public var normalized: CGPoint {
        let len = length
        return len > 0 ? CGPoint(x: x / len, y: y / len) : CGPoint(x: 0, y: 0)
    }

    /// Rotated 90 degrees counter-clockwise in a y-down space.
    public var perpendicular: CGPoint { CGPoint(x: -y, y: x) }

    public func distance(to other: CGPoint) -> CGFloat { (other - self).length }

    public func dot(_ other: CGPoint) -> CGFloat { x * other.x + y * other.y }
}

extension CGRect {
    public var center: CGPoint { CGPoint(x: midX, y: midY) }

    /// Moves the rect the minimum distance needed to lie inside `bounds`.
    public func clamped(into bounds: CGRect) -> CGRect {
        var rect = self
        rect.origin.x = min(max(rect.minX, bounds.minX), bounds.maxX - rect.width)
        rect.origin.y = min(max(rect.minY, bounds.minY), bounds.maxY - rect.height)
        return rect
    }
}
