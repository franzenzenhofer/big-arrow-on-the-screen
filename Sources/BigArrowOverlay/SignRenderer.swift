import AppKit
import BigArrowCore

/// The sign: a pill (or square) in the arrow colour with its border (see `ArrowBorder`), heavy
/// rounded text, and with `--close-button` an X in its right end. Edge, body and text are separate
/// images: the thin black edge goes below every white border of the arrow, so it never cuts
/// through the white where the shaft meets the sign, and the arrow's root is drawn between body
/// and text, so it blends into the body and never covers a letter.
public struct SignImage: @unchecked Sendable {
    public let edge: CGImage
    public let body: CGImage
    public let text: CGImage
    /// Size in points.
    public let size: CGSize
    public let fontSize: CGFloat
    public let lines: Int
}

public enum SignRenderer {
    static let paddingX: CGFloat = 30
    static let paddingY: CGFloat = 16
    static let outline: CGFloat = 3.5
    /// The thin black line of `--border white-black` and `black`, as wide as the arrow's per side.
    static let edge: CGFloat = 1.5
    static let seamOverlap: CGFloat = 0.5
    /// The X: its diameter as a share of the font size (at least the minimum, an easy target),
    /// the gap after the text, and its margin to the sign's edge. On a one-line pill it sits
    /// almost concentric with the rounded end.
    static let crossShare: CGFloat = 0.8
    static let crossMinimum: CGFloat = 26
    static let crossGap: CGFloat = 12
    static let crossMargin: CGFloat = 20

    /// Shrinks the font until the text fits in `maxLines` lines of `maxWidth`, never below the minimum.
    public static func render(text: String, appearance: SignAppearance, display: Display) -> SignImage {
        let maxTextWidth = display.frame.width * ArrowMetrics.maximumSignWidthShare - paddingX * 2
        var fontSize = appearance.size.metrics.fontSize
        var layout = measure(text, fontSize: fontSize, maxWidth: maxTextWidth, color: appearance.textTint)
        while layout.lines > ArrowMetrics.maximumLines, fontSize > ArrowMetrics.minimumFontSize {
            fontSize = max(fontSize - 2, ArrowMetrics.minimumFontSize)
            layout = measure(text, fontSize: fontSize, maxWidth: maxTextWidth, color: appearance.textTint)
        }
        let cross = appearance.closeMark == .cross ? max(crossMinimum, (fontSize * crossShare).rounded()) : 0
        let height = ceil(layout.size.height + paddingY * 2)
        let crossInset = min(height / 2, cross / 2 + crossMargin)
        let trailing = cross > 0 ? crossGap + cross / 2 + crossInset : paddingX
        let pill = CGSize(width: ceil(paddingX + layout.size.width + trailing), height: height)
        let textRect = CGRect(
            x: paddingX, y: (pill.height - layout.size.height) / 2, width: layout.size.width, height: layout.size.height
        )
        let canvas = Canvas(size: pill, scale: display.scale)
        return SignImage(
            edge: canvas.render { drawEdge(in: $0, pill: pill, appearance: appearance) },
            body: canvas.render { drawBody(in: $0, pill: pill, appearance: appearance) },
            text: canvas.render { context in
                // Text reads on every hue of the rainbow with a dark glow behind it.
                if appearance.effects.rainbow { context.setShadow(offset: .zero, blur: 4, color: CGColor(gray: 0, alpha: 0.9)) }
                drawText(layout, in: context, rect: textRect)
                if cross > 0 {
                    let center = CGPoint(x: pill.width - crossInset, y: pill.height / 2)
                    drawCross(in: context, center: center, diameter: cross, appearance: appearance)
                }
            },
            size: pill, fontSize: fontSize, lines: layout.lines
        )
    }

    /// The X button: a filled circle with the X on it, colours from `closeTint` and `closeXTint`.
    static func drawCross(in context: CGContext, center: CGPoint, diameter: CGFloat, appearance: SignAppearance) {
        let circle = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        context.setFillColor(appearance.closeTint.cgColor)
        context.fillEllipse(in: circle)
        let arm = diameter * 0.2
        context.setStrokeColor(appearance.closeXTint.cgColor)
        context.setLineWidth(max(2.5, diameter * 0.11))
        context.setLineCap(.round)
        context.strokeLineSegments(between: [
            CGPoint(x: center.x - arm, y: center.y - arm), CGPoint(x: center.x + arm, y: center.y + arm),
            CGPoint(x: center.x - arm, y: center.y + arm), CGPoint(x: center.x + arm, y: center.y - arm)
        ])
    }

    struct TextLayout {
        let string: NSAttributedString
        let size: CGSize
        let lines: Int
    }

    static func font(_ size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .heavy)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: size) ?? base
    }

    static func measure(_ text: String, fontSize: CGFloat, maxWidth: CGFloat, color: ArrowColor) -> TextLayout {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let font = font(fontSize)
        let string = NSAttributedString(string: text, attributes: [
            .font: font, .paragraphStyle: paragraph,
            .foregroundColor: NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
        ])
        let bounds = string.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        let lines = max(1, Int((bounds.height / lineHeight).rounded()))
        let size = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
        return TextLayout(string: string, size: size, lines: lines)
    }

    /// A rounded rect in the sign's corner style.
    struct Pill {
        let rect: CGRect
        let corners: SignCorners
    }

    /// The thin black line of `--border white-black` and `black`; nothing for the default.
    static func drawEdge(in context: CGContext, pill: CGSize, appearance: SignAppearance) {
        let width = edgeWidth(appearance.border)
        guard width > 0 else { return }
        let shape = Pill(rect: CGRect(origin: .zero, size: pill), corners: appearance.corners)
        stroke(shape, in: context, line: (width, appearance.edgeTint), fill: nil)
    }

    /// Fill and white border, inside the edge. It overlaps the edge by half a point so no seam shows.
    static func drawBody(in context: CGContext, pill: CGSize, appearance: SignAppearance) {
        let inset = max(0, edgeWidth(appearance.border) - seamOverlap)
        let shape = Pill(rect: CGRect(origin: .zero, size: pill).insetBy(dx: inset, dy: inset), corners: appearance.corners)
        let rainbow = appearance.effects.rainbow
        if rainbow { Rainbow.fill(pillPath(shape.rect, corners: shape.corners), in: context) }
        if appearance.border == .black {
            guard !rainbow else { return }
            context.addPath(pillPath(shape.rect, corners: shape.corners))
            context.setFillColor(appearance.color.cgColor)
            context.fillPath()
            return
        }
        stroke(shape, in: context, line: (outline, appearance.borderTint), fill: rainbow ? nil : appearance.color)
    }

    static func edgeWidth(_ border: ArrowBorder) -> CGFloat {
        border == .shadow ? 0 : edge
    }

    /// Strokes (and optionally fills) the pill with the line fully inside its rect.
    static func stroke(_ shape: Pill, in context: CGContext, line: (width: CGFloat, color: ArrowColor), fill: ArrowColor?) {
        let rect = shape.rect.insetBy(dx: line.width / 2, dy: line.width / 2)
        context.addPath(pillPath(rect, corners: shape.corners))
        context.setStrokeColor(line.color.cgColor)
        context.setLineWidth(line.width)
        if let fill {
            context.setFillColor(fill.cgColor)
            context.drawPath(using: .fillStroke)
        } else {
            context.strokePath()
        }
    }

    static func pillPath(_ rect: CGRect, corners: SignCorners) -> CGPath {
        let corner = corners.radius(height: rect.height)
        return CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    }

    static func drawText(_ text: TextLayout, in context: CGContext, rect textRect: CGRect) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        text.string.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// A transparent sRGB bitmap of a size in points at a backing scale.
struct Canvas {
    let size: CGSize
    let scale: CGFloat

    func render(_ draw: (CGContext) -> Void) -> CGImage {
        let width = Int(ceil(size.width * scale))
        let height = Int(ceil(size.height * scale))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { preconditionFailure("cannot create a \(width)x\(height) bitmap for the sign") }
        context.scaleBy(x: scale, y: scale)
        draw(context)
        guard let image = context.makeImage() else { preconditionFailure("cannot render the sign image") }
        return image
    }
}
