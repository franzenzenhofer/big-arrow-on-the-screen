import CoreGraphics

/// One display in global top-left logical points (origin = top-left of the primary display).
public struct Display: Equatable, Sendable, Codable {
    public let index: Int
    public let id: UInt32
    public let frame: CGRect
    /// Area below the menu bar and outside the Dock, same coordinate space as `frame`.
    public let visibleFrame: CGRect
    public let scale: CGFloat

    public init(index: Int, id: UInt32, frame: CGRect, visibleFrame: CGRect, scale: CGFloat) {
        self.index = index
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scale = scale
    }

    /// Half-open containment, so a point on a shared edge belongs to exactly one display.
    public func contains(_ point: CGPoint) -> Bool {
        point.x >= frame.minX && point.x < frame.maxX && point.y >= frame.minY && point.y < frame.maxY
    }

    /// Converts a global top-left point into this display's local top-left space.
    public func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }

    public func local(_ rect: CGRect) -> CGRect {
        CGRect(origin: local(rect.origin), size: rect.size)
    }

    /// Display-local bounds, origin zero.
    public var localBounds: CGRect { CGRect(origin: .zero, size: frame.size) }

    /// Visible frame (no menu bar, no Dock) in display-local top-left space.
    public var localVisibleBounds: CGRect { local(visibleFrame) }
}
