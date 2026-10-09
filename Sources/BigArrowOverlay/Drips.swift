import AppKit
import BigArrowCore

/// `--drip`: wet paint runs down from the sign's bottom edge and from the shaft. Each run grows,
/// lets a drop fall and starts again; without motion (and in `--png`) the runs hang still.
@MainActor
enum Drips {
    /// One run of paint, hanging from `top` (panel points, bottom-left) down by `length`.
    struct Run {
        let top: CGPoint
        let width: CGFloat
        let length: CGFloat
        /// Where the run's colours start: the hue of the paint above it.
        let hue: CGFloat
        let phase: Double
        /// Where it hangs below its edge, display-local top-left points, to check what it would cover.
        let extent: CGRect
        /// How far down from its top the run fades in: the part over the paint it leaves.
        let fade: CGFloat

        func with(hue: CGFloat, flip: CGAffineTransform) -> Run {
            Run(top: top.applying(flip), width: width, length: length, hue: hue, phase: phase, extent: extent, fade: fade)
        }
    }

    static let signSlot: CGFloat = 64
    static let shaftSpacing: CGFloat = 70
    static let fall: CGFloat = 170

    static func add(to layers: OverlayLayers, layout: OverlayLayout, look: SignAppearance, mode: AnimationMode) {
        for run in runs(layout, flip: layers.flip) {
            let colors = colors(run, look: look)
            let pictures = DripShape.pictures(run, colors: colors, look: look, scale: layout.display.scale)
            let fill = picture(pictures.fill, run: run, size: pictures.size)
            let border = picture(pictures.border, run: run, size: pictures.size)
            layers.root.insertSublayer(border, below: layers.sign)
            layers.root.insertSublayer(fill, below: layers.signText)
            guard mode == .full else { continue }
            let period = 2.4 + run.phase * 2
            for layer in [fill, border] { layer.add(grow(period: period, phase: run.phase), forKey: "drip") }
            let bead = bead(run, color: colors.last ?? look.color.cgColor, look: look, scale: layout.display.scale)
            bead.add(falling(period: period, phase: run.phase), forKey: "drip")
            layers.root.insertSublayer(bead, below: layers.signText)
        }
    }

    /// The paint above, getting a little deeper (or further round the rainbow) towards the drop.
    static func colors(_ run: Run, look: SignAppearance) -> [CGColor] {
        guard look.effects.rainbow else {
            let base = look.color
            let deep = ArrowColor(red: base.red * 0.8, green: base.green * 0.8, blue: base.blue * 0.8)
            return [base.cgColor, base.cgColor, deep.cgColor]
        }
        return (0...4).map { Rainbow.color(run.hue - CGFloat($0) * 0.08) }
    }

    static func picture(_ image: CGImage, run: Run, size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.contents = image
        layer.contentsScale = CGFloat(image.width) / size.width
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        layer.position = run.top
        return layer
    }

    /// Runs at uneven spots along the sign's straight bottom edge, and below the shaft where it
    /// runs level enough for paint to drip off it, away from the head. A run that would hang into
    /// the sign or across the shaft is left out.
    static func runs(_ layout: OverlayLayout, flip: CGAffineTransform) -> [Run] {
        let sign = layout.signRect
        let stroke = layout.size.metrics.stroke
        let corner = min(sign.height / 2, 30)
        let edge = max(0, sign.width - corner * 2)
        let slots = max(3, Int(edge / signSlot))
        let shaft = PathSampler.samples(along: layout.arrow.shaftPath, spacing: 6).map(\.point)
        var runs: [Run] = []
        for slot in 0..<slots where slot == 1 || PathSampler.jitter(slot, salt: 5) > 0.35 {
            let x = sign.minX + corner + edge * (CGFloat(slot) + 0.15 + PathSampler.jitter(slot, salt: 1) * 0.7) / CGFloat(slots)
            let drip = run(CGPoint(x: x, y: sign.maxY - 6), exit: sign.maxY, width: stroke * 0.85, index: slot)
            if clear(drip, of: shaft, stroke: stroke) { runs.append(drip.with(hue: Rainbow.signHue(x, sign: sign), flip: flip)) }
        }
        let headRoom = layout.size.metrics.headLength * 1.6
        let level = PathSampler.samples(along: layout.arrow.shaftPath, spacing: shaftSpacing).filter {
            abs($0.tangent.x) > 0.7 && hypot($0.point.x - layout.arrow.tip.x, $0.point.y - layout.arrow.tip.y) > headRoom
        }
        let keepOut = sign.insetBy(dx: -stroke, dy: -stroke)
        for (index, sample) in level.enumerated() {
            let width = stroke * 0.7
            let exit = sample.point.y + stroke * 0.5 / abs(sample.tangent.x)
            let drip = run(CGPoint(x: sample.point.x, y: exit - width * 0.9 - 2), exit: exit, width: width, index: index + slots)
            guard !drip.extent.intersects(keepOut), clear(drip, of: shaft, stroke: stroke) else { continue }
            runs.append(drip.with(hue: Rainbow.shaftHue(sample.share, layout: layout), flip: flip))
        }
        return runs
    }

    /// No part of the shaft below where the run leaves its edge.
    static func clear(_ drip: Run, of shaft: [CGPoint], stroke: CGFloat) -> Bool {
        let zone = drip.extent.insetBy(dx: -stroke / 2, dy: 0)
        return !shaft.contains { zone.contains($0) && $0.y > drip.extent.minY + stroke * 0.6 }
    }

    /// A run in display-local top-left points; `with(hue:flip:)` moves it to the panel.
    static func run(_ top: CGPoint, exit: CGFloat, width: CGFloat, index: Int) -> Run {
        let width = width * (0.8 + PathSampler.jitter(index, salt: 6) * 0.45)
        let stretch = PathSampler.jitter(index, salt: 2)
        let length = (exit - top.y) + width * (2.2 + stretch * stretch * 6)
        let extent = CGRect(x: top.x - width * 1.1, y: exit, width: width * 2.2, height: top.y + length + width * 0.7 - exit)
        let phase = Double(PathSampler.jitter(index, salt: 3))
        // Fades in until just before the border it crosses, so it melts into the paint above and still spills over the border.
        let fade = max(1.5, exit - top.y - 3.5)
        return Run(top: top, width: width, length: length, hue: 0, phase: phase, extent: extent, fade: fade)
    }

    static func bead(_ run: Run, color: CGColor, look: SignAppearance, scale: CGFloat) -> CALayer {
        let (image, size) = DripShape.bead(width: run.width, color: color, look: look, scale: scale)
        let layer = CALayer()
        layer.contents = image
        layer.contentsScale = scale
        layer.bounds = CGRect(origin: .zero, size: size)
        let pad = DripShape.borderWidth(look)
        layer.position = CGPoint(x: run.top.x, y: run.top.y - ceil(run.length + pad) + pad + run.width * 0.66)
        layer.opacity = 0
        return layer
    }

    /// Grows slowly, snaps back a little when the drop lets go.
    static func grow(period: Double, phase: Double) -> CAAnimation {
        let grow = CAKeyframeAnimation(keyPath: "transform.scale.y")
        grow.values = [0.45, 1, 0.7, 0.45]
        grow.keyTimes = [0, 0.72, 0.76, 1]
        return repeating(grow, period: period, phase: phase)
    }

    static func falling(period: Double, phase: Double) -> CAAnimation {
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 0, 1, 1, 0]
        fade.keyTimes = [0, 0.72, 0.73, 0.9, 1]
        let drop = CAKeyframeAnimation(keyPath: "transform.translation.y")
        drop.values = [0, 0, -fall]
        drop.keyTimes = [0, 0.72, 1]
        drop.timingFunctions = [CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(name: .easeIn)]
        let group = CAAnimationGroup()
        group.animations = [fade, drop]
        return repeating(group, period: period, phase: phase)
    }

    static func repeating(_ animation: CAAnimation, period: Double, phase: Double) -> CAAnimation {
        animation.duration = period
        animation.repeatCount = .infinity
        animation.timeOffset = period * phase
        return animation
    }
}
