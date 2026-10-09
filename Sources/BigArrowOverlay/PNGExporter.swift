import AppKit
import BigArrowCore
import ImageIO
import UniformTypeIdentifiers

/// Renders the exact layer tree of an arrow into a PNG instead of showing it (`--png`), for
/// documentation and for looking at a change without drawing over anybody's work.
@MainActor
public enum PNGExporter {
    /// The rendered region: the arrow's bounding box plus this margin, on a transparent background.
    static let margin: CGFloat = 40

    /// Writes the PNG and returns its top-left corner in global points and its pixels per point.
    @discardableResult
    public static func write(_ layout: OverlayLayout, sign: SignImage, appearance: SignAppearance, to url: URL) throws -> [Double] {
        let layers = OverlayLayers(layout: layout, sign: sign, appearance: appearance)
        let crop = cropRect(layout).insetBy(dx: -margin, dy: -margin)
            .intersection(CGRect(origin: .zero, size: layout.display.frame.size))
        let scale = layout.display.scale
        let image = Canvas(size: crop.size, scale: scale).render { context in
            context.translateBy(x: -crop.minX, y: -(layout.display.frame.height - crop.maxY))
            layers.root.render(in: context)
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

    /// Union of sign, arrow and mark in display-local top-left points.
    static func cropRect(_ layout: OverlayLayout) -> CGRect {
        var rect = layout.signRect.union(layout.arrow.shaftPath.boundingBoxOfPath).union(layout.arrow.headPath.boundingBoxOfPath)
        switch layout.mark {
        case .none: break
        case .box(let box): rect = rect.union(box)
        case .ring(let center, let radius):
            rect = rect.union(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return rect
    }
}
