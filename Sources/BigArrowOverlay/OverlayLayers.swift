import AppKit
import BigArrowCore

/// The finished layer tree for one layout. Paths come in display-local top-left points and
/// are flipped once here into the bottom-left space of the panel's content view.
///
/// The arrow reads as one shape: every contrast border sits below every coloured fill, so the
/// head and the shaft share one continuous border, and the coloured shaft is drawn over the
/// sign, so it grows out of the sign without a line across it. Without a shadow a thin black
/// edge runs outside the border; with `--shadow`, one shadow for the whole thing instead.
@MainActor
struct OverlayLayers {
    let root = CALayer()
    let shaftLayers: [CAShapeLayer]
    let headLayers: [CAShapeLayer]
    let markGroup = CALayer()
    let sign = CALayer()
    let signText = CALayer()
    /// Display-local top-left points to the panel's bottom-left points.
    let flip: CGAffineTransform

    static let outlineWidth: CGFloat = 6
    /// Added outside the border when there is no shadow: 1.5 pt of black on each side.
    static let edgeWidth: CGFloat = 3
    static let edgeColor = CGColor(gray: 0, alpha: 1)
    static let markLineWidth: CGFloat = 6

    init(layout: OverlayLayout, sign image: SignImage, appearance: SignAppearance) {
        let color = appearance.color
        let height = layout.display.frame.height
        let bounds = CGRect(origin: .zero, size: layout.display.frame.size)
        flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        let (shaft, head) = (Self.transformed(layout.arrow.shaftPath, flip), Self.transformed(layout.arrow.headPath, flip))
        let stroke = layout.size.metrics.stroke
        let edge = appearance.shadow == .none
        let rootPath = Self.transformed(layout.arrow.root.path, flip)
        let shaftBorders = Self.borders(color: color, edge: edge) { Self.stroked(shaft, color: $0, width: stroke + $1) }
        let headBorders = Self.borders(color: color, edge: edge) { Self.filled(head, color: $0, outline: $1) }
        let rootBorders = Self.borders(color: color, edge: edge) { Self.filled(rootPath, color: $0, outline: $1) }
        let colorShaft = Self.stroked(shaft, color: color.cgColor, width: stroke)
        let colorHead = Self.filled(head, color: color.cgColor, outline: 0)
        let colorRoot = Self.filled(rootPath, color: color.cgColor, outline: 0)
        shaftLayers = shaftBorders + [colorShaft]
        headLayers = headBorders + [colorHead]
        let tip = layout.arrow.tip.applying(flip)
        for layer in [root, markGroup] + shaftLayers + headLayers { layer.frame = bounds }
        for layer in headLayers { Self.pin(layer, at: tip, in: bounds) }
        markGroup.sublayers = Self.markLayers(layout.mark, flip: flip, color: color, edge: edge)
        let signFrame = Self.flipped(layout.signRect, height: height)
        for (layer, contents) in [(sign, image.body), (signText, image.text)] {
            layer.contents = contents
            layer.contentsScale = layout.display.scale
            layer.frame = signFrame
        }
        if !edge { Self.shadow(root) }
        // Every black edge below every white border, or the flare's edge cuts across the shaft's border.
        let parts = [shaftBorders, headBorders, rootBorders]
        let edges = parts.flatMap { $0.dropLast() }
        root.sublayers = [markGroup] + edges + parts.compactMap(\.last) + [sign, colorShaft, colorRoot, colorHead, signText]
    }

    /// The contrast border of one part, and below it, without a shadow, the black edge.
    static func borders(color: ArrowColor, edge: Bool, _ make: (CGColor, CGFloat) -> CAShapeLayer) -> [CAShapeLayer] {
        let border = make(color.contrast.cgColor, outlineWidth)
        return edge ? [make(edgeColor, outlineWidth + edgeWidth), border] : [border]
    }

    static func transformed(_ path: CGPath, _ transform: CGAffineTransform) -> CGPath {
        let result = CGMutablePath()
        result.addPath(path, transform: transform)
        return result
    }

    static func flipped(_ rect: CGRect, height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Moves a full-size layer's anchor to `point` so scale animations grow from there.
    static func pin(_ layer: CALayer, at point: CGPoint, in bounds: CGRect) {
        layer.anchorPoint = CGPoint(x: point.x / bounds.width, y: point.y / bounds.height)
        layer.position = point
    }

    static func stroked(_ path: CGPath, color: CGColor, width: CGFloat) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = path
        layer.fillColor = nil
        layer.strokeColor = color
        layer.lineWidth = width
        layer.lineCap = .round
        layer.lineJoin = .round
        return layer
    }

    static func filled(_ path: CGPath, color: CGColor, outline: CGFloat) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = path
        layer.fillColor = color
        layer.strokeColor = outline > 0 ? color : nil
        layer.lineWidth = outline
        layer.lineJoin = .round
        return layer
    }

    /// A short, soft drop shadow straight down (the content view is not flipped, so -y is down).
    static func shadow(_ layer: CALayer) {
        layer.shadowColor = CGColor(gray: 0, alpha: 1)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: -2)
    }

    static func markLayers(_ mark: TargetMark, flip: CGAffineTransform, color: ArrowColor, edge: Bool) -> [CALayer] {
        let path: CGPath
        switch mark {
        case .none:
            return []
        case .box(let rect):
            path = CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: [flip])
        case .ring(let center, let radius):
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            path = CGPath(ellipseIn: rect, transform: [flip])
        }
        // Border only, no fill: the human must see exactly what is being pointed at.
        return borders(color: color, edge: edge) { stroked(path, color: $0, width: markLineWidth + $1) }
            + [stroked(path, color: color.cgColor, width: markLineWidth)]
    }
}
