import AppKit
import BigArrowCore

/// Where a click ends the arrow: on the sign or the shaft, in the panel's bottom-left points.
/// Never near the head or on the target mark, so a click meant for the target still reaches it.
@MainActor
struct ClickRegion {
    let sign: CGRect
    let shaft: CGPath
    let tip: CGPoint
    let tipClearance: CGFloat
    let mark: CGRect?

    /// Extra width around the shaft that still counts as a hit, so the line is easy to click.
    static let shaftSlop: CGFloat = 12
    /// Distance around the tip, beyond the head's length, that always clicks through.
    static let tipMargin: CGFloat = 16

    init(layout: OverlayLayout, flip: CGAffineTransform) {
        let height = layout.display.frame.height
        sign = CGRect(x: layout.signRect.minX, y: height - layout.signRect.maxY,
                      width: layout.signRect.width, height: layout.signRect.height)
        let metrics = layout.size.metrics
        let path = CGMutablePath()
        path.addPath(layout.arrow.shaftPath, transform: flip)
        shaft = path.copy(strokingWithWidth: metrics.stroke + Self.shaftSlop, lineCap: .round, lineJoin: .round, miterLimit: 1)
        tip = layout.arrow.tip.applying(flip)
        tipClearance = metrics.headLength + Self.tipMargin
        mark = Self.markRect(layout.mark)?.applying(flip)
    }

    func contains(_ point: CGPoint) -> Bool {
        guard hypot(point.x - tip.x, point.y - tip.y) > tipClearance, !(mark?.contains(point) ?? false) else { return false }
        return sign.contains(point) || shaft.contains(point)
    }

    static func markRect(_ mark: TargetMark) -> CGRect? {
        let area: CGRect? = switch mark {
        case .none: nil
        case .box(let rect): rect
        case .ring(let center, let radius): CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        }
        return area?.insetBy(dx: -OverlayLayers.markLineWidth, dy: -OverlayLayers.markLineWidth)
    }
}

/// The overlay stays click-through except while the pointer is over the sign or the shaft:
/// a 60 Hz check of the pointer flips `ignoresMouseEvents`, so one click there ends the arrow
/// and every other click reaches the app underneath. Needs no permission.
@MainActor
final class ClickTracker {
    static let interval: TimeInterval = 1.0 / 60
    /// The arrow dims slightly under the pointer to show that a click removes it.
    static let hoverOpacity: Float = 0.82

    private weak var panel: NSPanel?
    private let root: CALayer
    private let region: ClickRegion
    private var timer: Timer?
    private var hovering = false

    init(panel: NSPanel, root: CALayer, region: ClickRegion) {
        self.panel = panel
        self.root = root
        self.region = region
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        panel?.ignoresMouseEvents = true
    }

    func tick() {
        guard let panel, panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        let local = CGPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY)
        let inside = region.contains(local)
        guard inside != hovering else { return }
        hovering = inside
        panel.ignoresMouseEvents = !inside
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        root.opacity = inside ? Self.hoverOpacity : 1
        CATransaction.commit()
    }
}
