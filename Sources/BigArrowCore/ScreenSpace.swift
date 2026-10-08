import CoreGraphics

/// Pure conversion between the input space (global top-left points, what Accessibility,
/// CGWindowList, Peekaboo and screenshots-in-points report) and AppKit's bottom-left space.
public struct ScreenSpace: Sendable {
    public let displays: [Display]

    public init(displays: [Display]) {
        self.displays = displays
    }

    /// Builds the display list from AppKit frames (bottom-left origin).
    /// The flip always uses the primary display height (`NSScreen.screens[0]`), never `NSScreen.main`.
    public static func fromAppKit(_ screens: [AppKitScreen]) -> ScreenSpace {
        guard let primaryHeight = screens.first?.frame.height else { return ScreenSpace(displays: []) }
        let displays = screens.enumerated().map { index, screen in
            Display(
                index: index,
                id: screen.id,
                frame: flip(screen.frame, primaryHeight: primaryHeight),
                visibleFrame: flip(screen.visibleFrame, primaryHeight: primaryHeight),
                scale: screen.scale
            )
        }
        return ScreenSpace(displays: displays)
    }

    /// `y' = H - y - height` in both directions.
    public static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.minY - rect.height, width: rect.width, height: rect.height)
    }

    public static func flip(_ point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    public var primaryHeight: CGFloat {
        displays.first.map { $0.frame.height } ?? 0
    }

    /// The display that contains `point`. Points on a shared edge belong to the right or lower display.
    public func display(containing point: CGPoint) throws -> Display {
        guard let match = displays.first(where: { $0.contains(point) }) else {
            throw BigArrowError.badInput(
                "point is outside every display: \(Int(point.x)),\(Int(point.y)) (displays: \(summary))"
            )
        }
        return match
    }

    /// Display by its 1-based number, as `--display N` and `doctor` count them.
    public func display(number: Int) throws -> Display {
        guard number >= 1, number <= displays.count else {
            throw BigArrowError.badInput("display \(number) does not exist, there are \(displays.count) (\(summary))")
        }
        return displays[number - 1]
    }

    /// One line describing every display, for error messages.
    public var summary: String {
        displays.map { display in
            let frame = display.frame
            return "\(display.index + 1): \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))"
        }.joined(separator: "; ")
    }
}

/// What the AppKit layer reports for one `NSScreen`, before flipping.
public struct AppKitScreen: Sendable {
    public let id: UInt32
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let scale: CGFloat

    public init(id: UInt32, frame: CGRect, visibleFrame: CGRect, scale: CGFloat) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scale = scale
    }
}
