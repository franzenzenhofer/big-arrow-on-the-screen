import AppKit
import BigArrowCore
import ImageIO
import UniformTypeIdentifiers

/// Renders the exact layer tree of an arrow into a PNG instead of showing it (`--png`), for
/// documentation and for looking at a change without drawing over anybody's work.
@MainActor
public enum PNGExporter {
    /// The rendered region: the arrow's bounding box plus this margin, on a transparent background.
    /// Wider than the shadow reaches, so the shadow is never cut off.
    static let margin: CGFloat = max(40, OverlayLayers.shadowReach + 12)

    /// Writes the PNG and returns its top-left corner in global points and its pixels per point.
    @discardableResult
    public static func write(_ layout: OverlayLayout, sign: SignImage, appearance: SignAppearance, to url: URL) throws -> [Double] {
        let layers = OverlayLayers(layout: layout, sign: sign, appearance: appearance)
        // A still frame: rainbow and drips render, flames and shake need motion.
        let picture = Effects.stage(layers, layout: layout, look: appearance, mode: .none)
        let crop = cropRect(layout, look: appearance).insetBy(dx: -margin, dy: -margin)
            .intersection(CGRect(origin: .zero, size: layout.display.frame.size))
        let scale = layout.display.scale
        let image = Canvas(size: crop.size, scale: scale).render { context in
            context.translateBy(x: -crop.minX, y: -(layout.display.frame.height - crop.maxY))
            picture.render(in: context)
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw BigArrowError.badInput("cannot write a PNG to \(url.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw BigArrowError.badInput("cannot write a PNG to \(url.path)")
        }
        return [layout.display.frame.minX + crop.minX, layout.display.frame.minY + crop.minY, scale]
    }

    /// Union of sign, arrow, mark and drips in display-local top-left points.
    static func cropRect(_ layout: OverlayLayout, look: SignAppearance) -> CGRect {
        var rect = layout.signRect.union(layout.arrow.shaftPath.boundingBoxOfPath).union(layout.arrow.headPath.boundingBoxOfPath)
        if look.effects.drip { rect = Drips.runs(layout, flip: .identity).reduce(rect) { $0.union($1.extent) } }
        switch layout.mark {
        case .none: break
        case .box(let box): rect = rect.union(box)
        case .ring(let center, let radius):
            rect = rect.union(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return rect
    }
}
