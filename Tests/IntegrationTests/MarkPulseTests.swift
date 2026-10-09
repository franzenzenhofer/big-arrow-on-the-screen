@testable import BigArrowCore
@testable import BigArrowOverlay
import QuartzCore
import Testing

/// The box or ring around the target pulses in place, computed offscreen; nothing is drawn.
/// Found by @jarombouts in PR #37: the mark's layer covers the whole display, so an unpinned
/// pulse scaled it around the display's centre and a box away from the centre swam.
@Suite("Mark pulse")
@MainActor
struct MarkPulseTests {
    let display = Display(index: 0, id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                          visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)

    @Test("At full pulse the box's centre stays on the target", arguments: [ArrowStyle.box, .ring])
    func markPulsesInPlace(style: ArrowStyle) throws {
        let appearance = SignAppearance(color: try ArrowColor.parse("blue"), size: .medium, corners: .round)
        let sign = SignRenderer.render(text: "Franz, click Save", appearance: appearance, display: display)
        let target = CGRect(x: 1300, y: 120, width: 80, height: 28)
        let layout = OverlayLayout.plan(OverlayLayout.Request(
            target: .rect(target), display: display, signSize: sign.size, style: style, size: .medium, forced: nil
        ))
        let layers = OverlayLayers(layout: layout, sign: sign, appearance: appearance)
        let area = try #require(layout.mark.area)
        let centre = CGPoint(x: area.midX, y: area.midY).applying(layers.flip)
        let before = layers.markGroup.convert(centre, to: layers.root)
        layers.markGroup.transform = CATransform3DMakeScale(Animator.pulseScale, Animator.pulseScale, 1)
        let after = layers.markGroup.convert(centre, to: layers.root)
        #expect(hypot(after.x - before.x, after.y - before.y) < 0.5)
    }
}
