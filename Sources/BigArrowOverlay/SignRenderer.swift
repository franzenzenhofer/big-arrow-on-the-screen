import AppKit
import BigArrowCore

/// The sign: a pill (or square) in the arrow colour with a contrast outline, plus heavy rounded
/// text in the contrast colour. Body and text are separate images so the arrow's root can be
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
        let pill = CGSize(
            width: ceil(layout.size.width + paddingX * 2), height: ceil(layout.size.height + paddingY * 2)
        )
        let canvas = Canvas(size: pill, scale: display.scale)
        return SignImage(
            body: canvas.render { drawBody(in: $0, pill: pill, appearance: appearance) },
            text: canvas.render { drawText(layout, in: $0, pill: pill) },
            size: pill, fontSize: fontSize, lines: layout.lines
        )
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
        let rect = CGRect(origin: .zero, size: pill).insetBy(dx: outline / 2, dy: outline / 2)
        let corner = appearance.corners.radius(height: rect.height)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        context.setFillColor(appearance.color.cgColor)
        context.setStrokeColor(appearance.color.contrast.cgColor)
        context.setLineWidth(outline)
        context.drawPath(using: .fillStroke)
    }

    static func drawText(_ text: TextLayout, in context: CGContext, pill: CGSize) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let textRect = CGRect(
            x: (pill.width - text.size.width) / 2, y: (pill.height - text.size.height) / 2,
            width: text.size.width, height: text.size.height
        )
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
