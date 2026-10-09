import AppKit
import BigArrowCore

/// The finished layer tree for one layout. Paths come in display-local top-left points and
/// are flipped once here into the bottom-left space of the panel's content view.
///
/// The arrow reads as one shape: every contrast border sits below every coloured fill, so the
/// head and the shaft share one continuous border, and the coloured shaft is drawn over the
/// sign, so it grows out of the sign without a line across it. By default one drop shadow for
/// the whole thing; `--border white-black` adds a thin black edge outside the border instead,
/// and `--border black` replaces the border with a thin black outline.
@MainActor
struct OverlayLayers {
    let root = CALayer()
    let shaftLayers: [CAShapeLayer]
    let headLayers: [CAShapeLayer]
    let markGroup = CALayer()
    let signEdge = CALayer()
    let sign = CALayer()
    let signText = CALayer()
    /// Display-local top-left points to the panel's bottom-left points.
    let flip: CGAffineTransform

    static let outlineWidth: CGFloat = 6
    /// The thin black line, added to a stroke's width: 1.5 pt on each side.
    static let edgeWidth: CGFloat = 3
    static let markLineWidth: CGFloat = 6
    static let shadowRadius: CGFloat = 10
    static let shadowDrop: CGFloat = 3
    /// How far the shadow reaches past the arrow: Core Animation blurs over about twice its radius.
    public static let shadowReach: CGFloat = shadowRadius * 2 + shadowDrop

    init(layout: OverlayLayout, sign image: SignImage, appearance: SignAppearance) {
        let color = appearance.color
        let height = layout.display.frame.height
        let bounds = CGRect(origin: .zero, size: layout.display.frame.size)
        flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        let (shaft, head) = (Self.transformed(layout.arrow.shaftPath, flip), Self.transformed(layout.arrow.headPath, flip))
        let stroke = layout.size.metrics.stroke
        let rootPath = Self.transformed(layout.arrow.root.path, flip)
        let shaftBorders = Self.borders(appearance) { Self.stroked(shaft, color: $0, width: stroke + $1) }
        let headBorders = Self.borders(appearance) { Self.filled(head, color: $0, outline: $1) }
        let rootBorders = Self.borders(appearance) { Self.filled(rootPath, color: $0, outline: $1) }
        let colorShaft = Self.stroked(shaft, color: color.cgColor, width: stroke)
        let colorHead = Self.filled(head, color: color.cgColor, outline: 0)
        let colorRoot = Self.filled(rootPath, color: color.cgColor, outline: 0)
        shaftLayers = shaftBorders + [colorShaft]
        headLayers = headBorders + [colorHead]
        let tip = layout.arrow.tip.applying(flip)
        for layer in [root, markGroup] + shaftLayers + headLayers { layer.frame = bounds }
        for layer in headLayers { Self.pin(layer, at: tip, in: bounds) }
        Self.fill(markGroup, with: layout.mark, flip: flip, appearance: appearance)
        let signFrame = Self.flipped(layout.signRect, height: height)
        for (layer, contents) in [(signEdge, image.edge), (sign, image.body), (signText, image.text)] {
            layer.contents = contents
            layer.contentsScale = layout.display.scale
            layer.frame = signFrame
        }
        if appearance.border.hasShadow { Self.shadow(root) }
        // Every black edge (the sign's too) below every white border, or a black line cuts through the white.
        let parts = [shaftBorders, headBorders, rootBorders]
        let edges = parts.flatMap { $0.dropLast() }
        root.sublayers = [markGroup] + edges + [signEdge] + parts.compactMap(\.last)
            + [sign, colorShaft, colorRoot, colorHead, signText]
    }

    /// The border layers of one part, outermost first.
    static func borders(_ look: SignAppearance, _ make: (CGColor, CGFloat) -> CAShapeLayer) -> [CAShapeLayer] {
        switch look.border {
        case .shadow: [make(look.borderTint.cgColor, outlineWidth)]
        case .whiteBlack: [make(look.edgeTint.cgColor, outlineWidth + edgeWidth), make(look.borderTint.cgColor, outlineWidth)]
        case .black: [make(look.edgeTint.cgColor, edgeWidth)]
        }
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

    /// The drop shadow, straight down (the content view is not flipped, so -y is down).
    static func shadow(_ layer: CALayer) {
        layer.shadowColor = CGColor(gray: 0, alpha: 1)
        layer.shadowOpacity = 0.35
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = CGSize(width: 0, height: -shadowDrop)
    }

    /// Puts the mark into its display-sized group and pins the group to the mark's centre, so the
    /// pulse grows the box or ring in place instead of around the display's centre.
    static func fill(_ group: CALayer, with mark: TargetMark, flip: CGAffineTransform, appearance: SignAppearance) {
        group.sublayers = markLayers(mark, flip: flip, appearance: appearance)
        guard let area = mark.area else { return }
        pin(group, at: CGPoint(x: area.midX, y: area.midY).applying(flip), in: group.bounds)
    }

    static func markLayers(_ mark: TargetMark, flip: CGAffineTransform, appearance: SignAppearance) -> [CALayer] {
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
        return borders(appearance) { stroked(path, color: $0, width: markLineWidth + $1) }
            + [stroked(path, color: appearance.color.cgColor, width: markLineWidth)]
    }
}
