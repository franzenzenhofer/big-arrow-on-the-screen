import AppKit
import BigArrowCore

/// The sign: a pill (or square) in the arrow colour with a contrast border (and, without a
/// shadow, a thin black edge outside it), plus heavy rounded
/// text in the contrast colour, and with `--close-button` an X in its right end. Body and text are separate images so the arrow's root can be
/// drawn between them: it blends into the body and never covers a letter.
public struct SignImage: @unchecked Sendable {
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
    /// The black edge outside the border when there is no shadow, as wide as the arrow's.
    static let edge: CGFloat = 1.5
    /// The X: its diameter as a share of the font size (at least the minimum, an easy target),
    /// the gap after the text, and its margin to the sign's edge. On a one-line pill it sits
    /// almost concentric with the rounded end.
    static let crossShare: CGFloat = 0.8
    static let crossMinimum: CGFloat = 26
    static let crossGap: CGFloat = 12
    static let crossMargin: CGFloat = 20

    /// Shrinks the font until the text fits in `maxLines` lines of `maxWidth`, never below the minimum.
    public static func render(text: String, appearance: SignAppearance, display: Display) -> SignImage {
        let color = appearance.color
        let maxTextWidth = display.frame.width * ArrowMetrics.maximumSignWidthShare - paddingX * 2
        var fontSize = appearance.size.metrics.fontSize
        var layout = measure(text, fontSize: fontSize, maxWidth: maxTextWidth, color: color)
        while layout.lines > ArrowMetrics.maximumLines, fontSize > ArrowMetrics.minimumFontSize {
            fontSize = max(fontSize - 2, ArrowMetrics.minimumFontSize)
            layout = measure(text, fontSize: fontSize, maxWidth: maxTextWidth, color: color)
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
            body: canvas.render { drawBody(in: $0, pill: pill, appearance: appearance) },
            text: canvas.render { context in
                drawText(layout, in: context, rect: textRect)
                if cross > 0 {
                    let center = CGPoint(x: pill.width - crossInset, y: pill.height / 2)
                    drawCross(in: context, center: center, diameter: cross, color: appearance.color)
                }
            },
            size: pill, fontSize: fontSize, lines: layout.lines
        )
    }

    /// A filled circle in the outline colour (black, or white on near-black signs) with the opposite X.
    static func drawCross(in context: CGContext, center: CGPoint, diameter: CGFloat, color: ArrowColor) {
        let circle = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        context.setFillColor(color.outline.cgColor)
        context.fillEllipse(in: circle)
        let arm = diameter * 0.2
        let lightCircle = color.outline.isLight
        context.setStrokeColor(CGColor(gray: lightCircle ? 0 : 1, alpha: 1))
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
            .foregroundColor: NSColor(srgbRed: color.contrast.red, green: color.contrast.green, blue: color.contrast.blue, alpha: 1)
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

    static func drawBody(in context: CGContext, pill: CGSize, appearance: SignAppearance) {
        let bounds = CGRect(origin: .zero, size: pill)
        let edgeWidth = appearance.shadow == .none ? edge : 0
        if edgeWidth > 0 {
            context.addPath(pillPath(bounds.insetBy(dx: edgeWidth / 2, dy: edgeWidth / 2), corners: appearance.corners))
            context.setStrokeColor(CGColor(gray: 0, alpha: 1))
            context.setLineWidth(edgeWidth)
            context.strokePath()
        }
        let inset = edgeWidth + outline / 2
        context.addPath(pillPath(bounds.insetBy(dx: inset, dy: inset), corners: appearance.corners))
        context.setFillColor(appearance.color.cgColor)
        context.setStrokeColor(appearance.color.contrast.cgColor)
        context.setLineWidth(outline)
        context.drawPath(using: .fillStroke)
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
