import AppKit
import BigArrowCore

/// The finished layer tree for one layout. Paths come in display-local top-left points and
/// are flipped once here into the bottom-left space of the panel's content view.
///
/// The arrow reads as one shape: every contrast outline sits below every coloured fill, so the
/// head and the shaft share one continuous outline, and the coloured shaft is drawn over the
/// sign, so it grows out of the sign without a line across it. One shadow for the whole thing.
@MainActor
struct OverlayLayers {
    let root = CALayer()
    let shaftLayers: [CAShapeLayer]
    let headLayers: [CAShapeLayer]
    let markGroup = CALayer()
    let sign = CALayer()
    let signText = CALayer()

    static let outlineWidth: CGFloat = 6
    static let markLineWidth: CGFloat = 6

    init(layout: OverlayLayout, sign image: SignImage, color: ArrowColor) {
        let height = layout.display.frame.height
        let bounds = CGRect(origin: .zero, size: layout.display.frame.size)
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        let shaft = Self.transformed(layout.arrow.shaftPath, flip)
        let head = Self.transformed(layout.arrow.headPath, flip)
        let stroke = layout.size.metrics.stroke
        let outlineShaft = Self.stroked(shaft, color: color.contrast.cgColor, width: stroke + Self.outlineWidth)
        let colorShaft = Self.stroked(shaft, color: color.cgColor, width: stroke)
        let outlineHead = Self.filled(head, color: color.contrast.cgColor, outline: Self.outlineWidth)
        let colorHead = Self.filled(head, color: color.cgColor, outline: 0)
        let rootPath = Self.transformed(layout.arrow.root.path, flip)
        let outlineRoot = Self.filled(rootPath, color: color.contrast.cgColor, outline: Self.outlineWidth)
        let colorRoot = Self.filled(rootPath, color: color.cgColor, outline: 0)
        shaftLayers = [outlineShaft, colorShaft]
        headLayers = [outlineHead, colorHead]
        let tip = layout.arrow.tip.applying(flip)
        for layer in [root, markGroup] + shaftLayers + headLayers { layer.frame = bounds }
        for layer in headLayers { Self.pin(layer, at: tip, in: bounds) }
        markGroup.sublayers = Self.markLayers(layout.mark, flip: flip, color: color)
        let signFrame = Self.flipped(layout.signRect, height: height)
        for (layer, contents) in [(sign, image.body), (signText, image.text)] {
            layer.contents = contents
            layer.contentsScale = layout.display.scale
            layer.frame = signFrame
        }
        Self.shadow(root)
        root.sublayers = [
            markGroup, outlineShaft, outlineHead, outlineRoot, sign, colorShaft, colorRoot, colorHead, signText
        ]
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

    static func shadow(_ layer: CALayer) {
        layer.shadowColor = CGColor(gray: 0, alpha: 1)
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: -3)
    }

    static func markLayers(_ mark: TargetMark, flip: CGAffineTransform, color: ArrowColor) -> [CALayer] {
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
        return [
            stroked(path, color: color.contrast.cgColor, width: markLineWidth + outlineWidth),
            stroked(path, color: color.cgColor, width: markLineWidth)
        ]
    }
}
