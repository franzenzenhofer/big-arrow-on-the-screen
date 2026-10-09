@testable import BigArrowCore
@testable import BigArrowOverlay
import CoreGraphics
import Testing

/// The sign's X and the click region, computed offscreen; nothing is drawn on the screen.
@Suite("Sign and click region")
@MainActor
struct SignAndClickTests {
    let display = Display(index: 0, id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                          visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)

    func appearance(_ mark: CloseMark) throws -> SignAppearance {
        var appearance = SignAppearance(color: try ArrowColor.parse("red"), size: .medium, corners: .round)
        appearance.closeMark = mark
        return appearance
    }

    @Test("The X widens the sign by at least its own diameter, so it never covers the text")
    func crossMakesRoom() throws {
        let plain = SignRenderer.render(text: "Franz, click Allow", appearance: try appearance(.none), display: display)
        let crossed = SignRenderer.render(text: "Franz, click Allow", appearance: try appearance(.cross), display: display)
        #expect(crossed.size.height == plain.size.height)
        #expect(crossed.size.width - plain.size.width >= SignRenderer.crossMinimum)
    }

    @Test("A click counts on the sign and the shaft, never near the tip or on the target")
    func region() throws {
        let sign = SignRenderer.render(text: "Franz, click Allow", appearance: try appearance(.none), display: display)
        let layout = OverlayLayout.plan(OverlayLayout.Request(
            target: .point(CGPoint(x: 300, y: 250)), display: display, signSize: sign.size,
            style: .arrow, size: .medium, forced: .bottomRight
        ))
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: display.frame.height)
        let region = ClickRegion(layout: layout, flip: flip)
        let signCenter = CGPoint(x: layout.signRect.midX, y: layout.signRect.midY).applying(flip)
        #expect(region.contains(signCenter))
        #expect(!region.contains(CGPoint(x: 300, y: 250).applying(flip)))
        #expect(!region.contains(layout.arrow.tip.applying(flip)))
        #expect(!region.contains(CGPoint(x: 1400, y: 60)))
        let shaftMiddle = layout.arrow.shaftPath.boundingBoxOfPath.center.applying(flip)
        let onShaft = (0..<40).contains { step in
            region.contains(CGPoint(x: shaftMiddle.x + CGFloat(step - 20) * 3, y: shaftMiddle.y))
        }
        #expect(onShaft)
    }
}
