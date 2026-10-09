import AppKit
import BigArrowCore

/// The picture of one run of paint: a wide lip where it leaves the edge, a narrow stem and a
/// heavy drop at the end, filled top to bottom with its colours and a wet highlight. Its border
/// is a separate picture that goes below the sign, so it joins the sign's border seamlessly.
enum DripShape {
    struct Pictures {
        let fill: CGImage
        let border: CGImage
        let size: CGSize
    }

    /// The border's width on each side, as wide as the sign's.
    static func borderWidth(_ look: SignAppearance) -> CGFloat {
        look.border == .black ? 1.5 : 3.5
    }

    static func borderColor(_ look: SignAppearance) -> CGColor {
        look.border == .black ? look.edgeTint.cgColor : look.borderTint.cgColor
    }

    static func size(width: CGFloat, length: CGFloat, pad: CGFloat) -> CGSize {
        CGSize(width: ceil((width * 1.1 + pad) * 2), height: ceil(length + pad))
    }

    /// The outline, lip at the top edge of `size`, drop at the bottom (bottom-left origin).
    static func path(width: CGFloat, in size: CGSize, pad: CGFloat) -> CGPath {
        let (center, top, bottom) = (size.width / 2, size.height, pad)
        let (stem, drop) = (width / 2, width * 0.66)
        let (lip, neck) = (stem + width * 0.6, top - width * 0.9)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: center - lip, y: top + 1))
        path.addLine(to: CGPoint(x: center - lip, y: top))
        path.addQuadCurve(to: CGPoint(x: center - stem, y: neck), control: CGPoint(x: center - stem, y: top))
        path.addLine(to: CGPoint(x: center - stem, y: bottom + drop * 2.4))
        path.addQuadCurve(to: CGPoint(x: center - drop, y: bottom + drop), control: CGPoint(x: center - stem, y: bottom + drop * 1.6))
        path.addArc(center: CGPoint(x: center, y: bottom + drop), radius: drop, startAngle: .pi, endAngle: 0, clockwise: false)
        path.addQuadCurve(to: CGPoint(x: center + stem, y: bottom + drop * 2.4), control: CGPoint(x: center + stem, y: bottom + drop * 1.6))
        path.addLine(to: CGPoint(x: center + stem, y: neck))
        path.addQuadCurve(to: CGPoint(x: center + lip, y: top), control: CGPoint(x: center + stem, y: top))
        path.addLine(to: CGPoint(x: center + lip, y: top + 1))
        path.closeSubpath()
        return path
    }

    static func pictures(_ run: Drips.Run, colors: [CGColor], look: SignAppearance, scale: CGFloat) -> Pictures {
        let pad = borderWidth(look)
        let size = size(width: run.width, length: run.length, pad: pad)
        let outline = path(width: run.width, in: size, pad: pad)
        let canvas = Canvas(size: size, scale: scale)
        let fill = canvas.render { context in
            paint(outline, colors: colors, in: context, height: size.height)
            gloss(width: run.width, in: context, size: size, pad: pad)
            fadeIn(context, size: size, over: run.fade)
        }
        let border = canvas.render { context in
            context.addPath(outline)
            context.setStrokeColor(borderColor(look))
            context.setFillColor(borderColor(look))
            context.setLineWidth(pad * 2)
            context.setLineJoin(.round)
            context.drawPath(using: .fillStroke)
        }
        return Pictures(fill: fill, border: border, size: size)
    }

    /// The colours top to bottom.
    static func paint(_ outline: CGPath, colors: [CGColor], in context: CGContext, height: CGFloat) {
        guard let gradient = CGGradient(colorsSpace: ColorSpaces.sRGB, colors: colors as CFArray, locations: nil) else { return }
        context.saveGState()
        context.addPath(outline)
        context.clip()
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: .zero, options: [])
        context.restoreGState()
    }

    /// Erases the top smoothly, from clear at the very top to solid `distance` below it.
    static func fadeIn(_ context: CGContext, size: CGSize, over distance: CGFloat) {
        let colors = [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: ColorSpaces.sRGB, colors: colors, locations: [0, 1]) else { return }
        context.saveGState()
        context.setBlendMode(.destinationOut)
        context.drawLinearGradient(
            gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: size.height - distance),
            options: [.drawsBeforeStartLocation]
        )
        context.restoreGState()
    }

    /// A soft light streak down the stem and a glint on the drop: it looks wet.
    static func gloss(width: CGFloat, in context: CGContext, size: CGSize, pad: CGFloat) {
        let (center, drop) = (size.width / 2, width * 0.66)
        context.saveGState()
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.4))
        context.setLineWidth(max(1.5, width * 0.16))
        context.setLineCap(.round)
        let streak = center - width * 0.2
        if size.height - width * 1.2 > pad + drop * 2.6 {
            context.strokeLineSegments(between: [
                CGPoint(x: streak, y: size.height - width * 1.2), CGPoint(x: streak, y: pad + drop * 2.6)
            ])
        }
        context.setFillColor(CGColor(gray: 1, alpha: 0.6))
        let glint = drop * 0.5
        context.fillEllipse(in: CGRect(x: center - drop * 0.55, y: pad + drop * 1.05, width: glint, height: glint * 0.8))
        context.restoreGState()
    }

    /// The falling drop: a bead with its border and a glint.
    static func bead(width: CGFloat, color: CGColor, look: SignAppearance, scale: CGFloat) -> (CGImage, CGSize) {
        let pad = borderWidth(look)
        let radius = width * 0.55
        let side = ceil((radius + pad) * 2)
        let image = Canvas(size: CGSize(width: side, height: side), scale: scale).render { context in
            let circle = CGRect(x: pad, y: pad, width: radius * 2, height: radius * 2)
            context.setFillColor(borderColor(look))
            context.fillEllipse(in: circle.insetBy(dx: -pad, dy: -pad))
            context.setFillColor(color)
            context.fillEllipse(in: circle)
            context.setFillColor(CGColor(gray: 1, alpha: 0.6))
            context.fillEllipse(in: CGRect(x: pad + radius * 0.45, y: pad + radius * 1.1, width: radius * 0.5, height: radius * 0.4))
        }
        return (image, CGSize(width: side, height: side))
    }
}
