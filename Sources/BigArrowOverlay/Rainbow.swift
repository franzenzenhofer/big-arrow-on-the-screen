import AppKit
import BigArrowCore

/// `--rainbow`, without masks, so `--png` renders it too: the sign body is filled with a gradient
/// in its image, the root with the same gradient, and the shaft is a picture whose hue carries on
/// from where it leaves the sign.
enum Rainbow {
    /// Points of shaft per hue step.
    static let step: CGFloat = 2
    static let saturation: CGFloat = 0.85

    static func color(_ hue: CGFloat) -> CGColor {
        let wrapped = hue - floor(hue)
        return NSColor(hue: wrapped, saturation: saturation, brightness: 1, alpha: 1).usingColorSpace(.sRGB)?.cgColor
            ?? CGColor(red: 1, green: 0, blue: 0, alpha: 1)
    }

    /// A closed loop of hues, the last equal to the first.
    static func loop(from hue: CGFloat) -> [CGColor] {
        (0...12).map { color(hue - CGFloat($0) / 12) }
    }

    /// Fills `path` with a left-to-right rainbow spanning `span` (default: the path's own width).
    static func fill(_ path: CGPath, in context: CGContext, span: ClosedRange<CGFloat>? = nil) {
        let box = path.boundingBoxOfPath
        let span = span ?? box.minX...box.maxX
        guard let gradient = CGGradient(colorsSpace: ColorSpaces.sRGB, colors: loop(from: 0).dropLast() as CFArray, locations: nil) else {
            return
        }
        context.saveGState()
        context.addPath(path)
        context.clip()
        let options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        let (start, end) = (CGPoint(x: span.lowerBound, y: 0), CGPoint(x: span.upperBound, y: 0))
        context.drawLinearGradient(gradient, start: start, end: end, options: options)
        context.restoreGState()
    }

    /// The sign's hue at `x` (display-local points): its gradient runs once through the hues, left to right.
    static func signHue(_ x: CGFloat, sign: CGRect) -> CGFloat {
        -min(1, max(0, (x - sign.minX) / sign.width)) * 11 / 12
    }

    /// The shaft's hue at `share` of its length: it picks up the sign's hue where it leaves the sign.
    static func shaftHue(_ share: CGFloat, layout: OverlayLayout) -> CGFloat {
        signHue(layout.arrow.tail.x, sign: layout.signRect) + share
    }

    /// Paints shaft, root, head and mark to continue the sign's gradient. One still picture, so
    /// nothing can drift apart.
    @MainActor
    static func paint(_ layers: OverlayLayers, layout: OverlayLayout) {
        guard let colorShaft = layers.shaftLayers.last, let colorHead = layers.headLayers.last else { return }
        colorShaft.opacity = 0
        // Shaft above root, so it fades in over the root.
        layers.root.insertSublayer(shaftPicture(layers, layout: layout, width: colorShaft.lineWidth), above: layers.rootFill)
        layers.root.insertSublayer(rootPicture(layers, layout: layout), above: layers.rootFill)
        layers.rootFill.opacity = 0
        colorHead.fillColor = color(shaftHue(1, layout: layout))
        for case let mark as CAShapeLayer in layers.markGroup.sublayers?.suffix(1) ?? [] {
            mark.strokeColor = color(shaftHue(1, layout: layout))
        }
    }

    /// The shaft as one picture whose hue changes every `step` points, so no bands show. It fades
    /// in over the root, so the sign's colour melts into the shaft's.
    @MainActor
    static func shaftPicture(_ layers: OverlayLayers, layout: OverlayLayout, width: CGFloat) -> CALayer {
        let samples = PathSampler.samples(along: layout.arrow.shaftPath, spacing: step)
        let box = layout.arrow.shaftPath.boundingBoxOfPath.insetBy(dx: -width, dy: -width).applying(layers.flip).integral
        let tail = layout.arrow.tail.applying(layers.flip)
        let picture = CALayer()
        picture.frame = box
        picture.contentsScale = layout.display.scale
        picture.contents = Canvas(size: box.size, scale: layout.display.scale).render { context in
            context.translateBy(x: -box.minX, y: -box.minY)
            context.setLineWidth(width)
            context.setLineCap(.round)
            for (from, to) in zip(samples, samples.dropFirst()) {
                context.setStrokeColor(color(shaftHue(to.share, layout: layout)))
                context.strokeLineSegments(between: [from.point.applying(layers.flip), to.point.applying(layers.flip)])
            }
            let inside = ArrowGeometry.tailInset
            erase(around: tail, from: inside, to: inside + layout.arrow.root.flareLength, in: context)
        }
        return picture
    }

    /// Clear within `from` of `center`, solid again from `to` outwards.
    static func erase(around center: CGPoint, from inner: CGFloat, to outer: CGFloat, in context: CGContext) {
        let colors = [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: ColorSpaces.sRGB, colors: colors, locations: [0, 1]) else { return }
        context.saveGState()
        context.setBlendMode(.destinationOut)
        context.drawRadialGradient(
            gradient, startCenter: center, startRadius: inner, endCenter: center, endRadius: outer, options: [.drawsBeforeStartLocation]
        )
        context.restoreGState()
    }

    /// The flared root filled with the sign's own gradient, so it melts into the sign.
    @MainActor
    static func rootPicture(_ layers: OverlayLayers, layout: OverlayLayout) -> CALayer {
        let path = layers.rootFill.path ?? CGMutablePath()
        let box = path.boundingBoxOfPath.insetBy(dx: -1, dy: -1).integral
        let sign = OverlayLayers.flipped(layout.signRect, height: layout.display.frame.height)
        let picture = CALayer()
        picture.frame = box
        picture.contentsScale = layout.display.scale
        picture.contents = Canvas(size: box.size, scale: layout.display.scale).render { context in
            context.translateBy(x: -box.minX, y: -box.minY)
            fill(path, in: context, span: sign.minX...sign.maxX)
        }
        return picture
    }
}
