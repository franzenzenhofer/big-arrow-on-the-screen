import AppKit

/// How the arrow enters and leaves.
public enum AnimationMode: Sendable, Equatable {
    /// Draw-on shaft, spring head and sign, pulsing head.
    case full
    /// Reduce Motion: short fades only, no pulse.
    case reduced
    /// `--no-animation`: final frame immediately, no fades.
    case none

    @MainActor
    public static func resolve(disabled: Bool) -> AnimationMode {
        if disabled { return .none }
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .reduced : .full
    }

    var fadeOut: CFTimeInterval {
        switch self {
        case .full: 0.2
        case .reduced: 0.1
        case .none: 0
        }
    }
}

/// Core Animation only, so the render server does the work and the process stays idle.
@MainActor
enum Animator {
    static let drawOn: CFTimeInterval = 0.45
    static let pulsePeriod: CFTimeInterval = 0.9
    static let pulseScale: CGFloat = 1.08

    static func enter(_ layers: OverlayLayers, mode: AnimationMode) {
        switch mode {
        case .none: return
        case .reduced: fade(layers.root, from: 0, to: 1, duration: 0.1)
        case .full: full(layers)
        }
    }

    private static func full(_ layers: OverlayLayers) {
        let now = CACurrentMediaTime()
        for shaft in layers.shaftLayers {
            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0
            draw.toValue = 1
            draw.duration = drawOn
            draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shaft.add(draw, forKey: "drawOn")
        }
        for head in layers.headLayers {
            spring(head, from: 0.2, begin: now + drawOn * 0.8)
            pulse(head, begin: now + drawOn + 0.5)
        }
        for layer in [layers.signEdge, layers.sign, layers.signText] {
            spring(layer, from: 0.8, begin: now)
            fade(layer, from: 0, to: 1, duration: 0.18)
        }
        fade(layers.markGroup, from: 0, to: 1, duration: 0.25)
        pulse(layers.markGroup, begin: now + drawOn + 0.5)
    }

    private static func spring(_ layer: CALayer, from scale: CGFloat, begin: CFTimeInterval) {
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = scale
        spring.toValue = 1
        spring.damping = 11
        spring.stiffness = 220
        spring.mass = 1
        spring.duration = spring.settlingDuration
        spring.beginTime = begin
        spring.fillMode = .backwards
        layer.add(spring, forKey: "springIn")
    }

    private static func pulse(_ layer: CALayer, begin: CFTimeInterval) {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = pulseScale
        pulse.duration = pulsePeriod / 2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.beginTime = begin
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(pulse, forKey: "pulse")
    }

    static func fade(_ layer: CALayer, from: Float, to: Float, duration: CFTimeInterval) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from
        fade.toValue = to
        fade.duration = duration
        fade.fillMode = .both
        layer.opacity = to
        layer.add(fade, forKey: "fade")
    }
}
