import AppKit
import BigArrowCore

/// `--flames`: fire around the sign, along the shaft and around the head, behind the arrow, so
/// only the flames licking past its edges show. Every spot burns on its own: its own random seed,
/// its own lean and its own gusts, with big tongues, a hot core and stray embers. Particle
/// emitters, so the render server animates them and the process stays idle.
@MainActor
enum Flames {
    /// One place that burns, in panel points (bottom-left), and how fiercely.
    struct Site {
        let point: CGPoint
        let radius: CGFloat
        let heat: Float
    }

    struct Sprites {
        let tongue: CGImage
        let ember: CGImage
    }

    static let signSpacing: CGFloat = 26
    static let shaftSpacing: CGFloat = 30

    static func layer(_ layers: OverlayLayers, layout: OverlayLayout) -> CALayer {
        let container = CALayer()
        container.frame = layers.root.frame
        let sprites = Sprites(tongue: tongueSprite(), ember: emberSprite())
        container.sublayers = sites(layers, layout: layout).enumerated().map { index, site in
            emitter(site, index: index, sprites: sprites)
        }
        return container
    }

    /// Round the sign (fiercest on top, where fire rises), along the shaft and at the head.
    static func sites(_ layers: OverlayLayers, layout: OverlayLayout) -> [Site] {
        let sign = layout.signRect
        let corner = min(sign.height / 2, 30)
        let outline = CGPath(roundedRect: sign, cornerWidth: corner, cornerHeight: corner, transform: nil)
        let signSites = PathSampler.samples(along: outline, spacing: signSpacing).map { sample -> Site in
            let height = (sign.maxY - sample.point.y) / max(1, sign.height)
            return Site(point: sample.point.applying(layers.flip), radius: 6, heat: Float(0.45 + height * 0.85))
        }
        let stroke = layout.size.metrics.stroke
        let shaftSites = PathSampler.samples(along: layout.arrow.shaftPath, spacing: shaftSpacing)
            .filter { !sign.contains($0.point) }
            .map { Site(point: $0.point.applying(layers.flip), radius: stroke / 2, heat: 0.7) }
        let points = layout.arrow.headPoints
        let share = 1 / CGFloat(max(1, points.count))
        let head = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x * share, y: $0.y + $1.y * share) }
        let headSite = Site(point: head.applying(layers.flip), radius: layout.size.metrics.headWidth / 3, heat: 1.1)
        return signSites + shaftSites + [headSite]
    }

    static func emitter(_ site: Site, index: Int, sprites: Sprites) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = site.point
        emitter.emitterShape = .circle
        emitter.emitterSize = CGSize(width: site.radius * 2, height: site.radius * 2)
        emitter.renderMode = .additive
        emitter.seed = UInt32.random(in: 0...UInt32.max)
        let lean = (PathSampler.jitter(index, salt: 9) - 0.5) * 0.5
        let heat = site.heat
        emitter.emitterCells = [
            tongue(sprites.tongue, heat: heat, lean: lean),
            core(sprites.tongue, heat: heat),
            ember(sprites.ember, heat: heat)
        ]
        emitter.add(gusts(index: index), forKey: "gusts")
        return emitter
    }

    /// The burn rate and flame size wander, each spot on its own rhythm.
    static func gusts(index: Int) -> CAAnimation {
        let values = (0..<9).map { PathSampler.jitter(index * 9 + $0, salt: 10) }
        let rate = CAKeyframeAnimation(keyPath: "birthRate")
        rate.values = (values + [values[0]]).map { 0.35 + $0 * 1.3 }
        let size = CAKeyframeAnimation(keyPath: "scale")
        size.values = (values.reversed() + [values[8]]).map { 0.7 + $0 * 0.7 }
        let group = CAAnimationGroup()
        group.animations = [rate, size]
        let duration = 1.4 + Double(PathSampler.jitter(index, salt: 11)) * 1.8
        for animation in [rate, size, group] { animation.duration = duration }
        rate.calculationMode = .cubic
        size.calculationMode = .cubic
        group.repeatCount = .infinity
        group.timeOffset = duration * Double(PathSampler.jitter(index, salt: 12))
        return group
    }

    /// Big licks that rise, lean a little, and burn from yellow through orange to red.
    static func tongue(_ sprite: CGImage, heat: Float, lean: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = sprite
        (cell.birthRate, cell.lifetime, cell.lifetimeRange) = (16 * heat, 0.75 * heat, 0.4)
        (cell.velocity, cell.velocityRange) = (55 + 35 * CGFloat(heat), 40)
        (cell.emissionLongitude, cell.emissionRange) = (.pi / 2 + lean, .pi / 7)
        (cell.yAcceleration, cell.xAcceleration) = (150, lean * 90)
        (cell.scale, cell.scaleRange, cell.scaleSpeed) = (0.75, 0.45, -0.7)
        (cell.spinRange, cell.alphaSpeed) = (1.6, -1.25)
        cell.color = CGColor(red: 1, green: 0.72, blue: 0.28, alpha: 0.85)
        (cell.redRange, cell.greenRange, cell.greenSpeed, cell.blueSpeed) = (0.1, 0.15, -1.3, -1)
        return cell
    }

    /// The hot white-yellow base of the fire, short and bright.
    static func core(_ sprite: CGImage, heat: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = sprite
        (cell.birthRate, cell.lifetime, cell.lifetimeRange) = (12 * heat, 0.3, 0.12)
        (cell.velocity, cell.velocityRange, cell.emissionLongitude, cell.emissionRange) = (30, 18, .pi / 2, .pi / 5)
        (cell.scale, cell.scaleRange, cell.scaleSpeed, cell.alphaSpeed) = (0.38, 0.14, -0.5, -2.6)
        cell.color = CGColor(red: 1, green: 0.95, blue: 0.72, alpha: 0.9)
        cell.greenSpeed = -0.9
        return cell
    }

    /// Now and then a spark that flies off high and drifts.
    static func ember(_ sprite: CGImage, heat: Float) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = sprite
        (cell.birthRate, cell.lifetime, cell.lifetimeRange) = (0.9 * heat, 1.6, 0.9)
        (cell.velocity, cell.velocityRange, cell.emissionLongitude, cell.emissionRange) = (130, 80, .pi / 2, .pi / 3)
        cell.yAcceleration = 40
        (cell.scale, cell.scaleRange, cell.alphaSpeed) = (0.5, 0.3, -0.6)
        cell.color = CGColor(red: 1, green: 0.62, blue: 0.2, alpha: 1)
        (cell.greenRange, cell.greenSpeed) = (0.2, -0.3)
        return cell
    }

    /// A soft, tall tongue, brightest low down; the cell colour tints it.
    static func tongueSprite() -> CGImage {
        let size = CGSize(width: 24, height: 48)
        return Canvas(size: size, scale: 2).render { context in
            let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0.45), CGColor(gray: 1, alpha: 0)] as CFArray
            guard let gradient = CGGradient(colorsSpace: ColorSpaces.sRGB, colors: colors, locations: [0, 0.4, 1]) else { return }
            context.scaleBy(x: 1, y: 2)
            let center = CGPoint(x: size.width / 2, y: size.height / 6)
            let radius = size.width / 2
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
    }

    /// A tiny hard spark.
    static func emberSprite() -> CGImage {
        Canvas(size: CGSize(width: 6, height: 6), scale: 2).render { context in
            let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray
            guard let gradient = CGGradient(colorsSpace: ColorSpaces.sRGB, colors: colors, locations: [0.3, 1]) else { return }
            let center = CGPoint(x: 3, y: 3)
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: 3, options: [])
        }
    }
}
