import BigArrowCore
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// Renders the arrow paths with plain CoreGraphics and compares them to a committed golden PNG.
/// Record a new golden with `BIGARROW_RECORD_GOLDEN=1 swift test --filter GoldenSnapshot`.
@Suite("Golden snapshot")
struct GoldenSnapshotTests {
    static let canvas = CGSize(width: 640, height: 400)
    static let goldenName = "golden-arrow"
    /// Share of pixels allowed to differ by more than `channelTolerance` (anti-aliasing across OS versions).
    static let allowedDifference = 0.005
    static let channelTolerance = 24

    @Test("The arrow renders like the golden file")
    func matchesGolden() throws {
        let rendered = try render()
        let url = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
            .appendingPathComponent("\(Self.goldenName).png")
        if ProcessInfo.processInfo.environment["BIGARROW_RECORD_GOLDEN"] == "1" {
            try write(rendered, to: sourceFixture())
            return
        }
        let golden = try #require(CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        let difference = try Self.difference(rgba(rendered), rgba(golden))
        #expect(difference <= Self.allowedDifference, "\(difference * 100)% of pixels differ")
    }

    func render() throws -> CGImage {
        let display = Display(index: 0, id: 1, frame: CGRect(origin: .zero, size: Self.canvas),
                              visibleFrame: CGRect(origin: .zero, size: Self.canvas), scale: 1)
        let layout = OverlayLayout.plan(OverlayLayout.Request(
            target: .point(CGPoint(x: 470, y: 120)), display: display, signSize: CGSize(width: 220, height: 64),
            style: .arrow, size: .medium, forced: .bottomLeft
        ))
        let context = try #require(CGContext(
            data: nil, width: Int(Self.canvas.width), height: Int(Self.canvas.height), bitsPerComponent: 8,
            bytesPerRow: 0, space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.translateBy(x: 0, y: Self.canvas.height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: Self.canvas))
        let color = try ArrowColor.parse("red").cgColor
        context.setStrokeColor(color)
        context.setLineWidth(ArrowSize.medium.metrics.stroke)
        context.setLineCap(.round)
        context.addPath(layout.arrow.shaftPath)
        context.strokePath()
        context.setFillColor(color)
        context.addPath(layout.arrow.headPath)
        context.fillPath()
        context.addPath(layout.arrow.root.path)
        context.fillPath()
        context.fill(layout.signRect)
        return try #require(context.makeImage())
    }

    func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }

    static func difference(_ lhs: [UInt8], _ rhs: [UInt8]) throws -> Double {
        try #require(lhs.count == rhs.count, "image sizes differ")
        var differing = 0
        for pixel in stride(from: 0, to: lhs.count, by: 4) {
            let delta = (0..<4).map { abs(Int(lhs[pixel + $0]) - Int(rhs[pixel + $0])) }.max() ?? 0
            if delta > channelTolerance { differing += 1 }
        }
        return Double(differing) / Double(lhs.count / 4)
    }

    func sourceFixture() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(Self.goldenName).png")
    }

    func write(_ image: CGImage, to url: URL) throws {
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
    }
}
