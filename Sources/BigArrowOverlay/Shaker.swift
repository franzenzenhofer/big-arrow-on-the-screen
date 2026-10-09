import AppKit
import BigArrowCore

/// `--shake`: the whole arrow vibrates, jolting to random spots around where it rests. Mild and
/// insistent shake in bursts and rest in between; angry and topiramate never rest, and
/// topiramate's sign throbs on top.
@MainActor
enum Shaker {
    static let jolts = 40
    static let burst = 10

    /// Adds the same jolts to every layer in `targets`, in one transaction, so they move as one.
    static func shake(_ targets: [CALayer], layers: OverlayLayers, level: ShakeLevel) {
        let count = level.period > 0 ? burst : jolts
        let offsets = (0..<count).map { index -> CGPoint in
            let angle = PathSampler.jitter(index, salt: 7) * 2 * .pi
            let reach = level.amplitude * (0.4 + PathSampler.jitter(index, salt: 8) * 0.6)
            return CGPoint(x: cos(angle) * reach, y: sin(angle) * reach)
        } + [.zero]
        let busy = level.jolt * Double(offsets.count)
        let duration = max(busy, level.period)
        // In bursts, a last key holds still until the period ends.
        let rest: [CGPoint] = duration > busy ? [.zero] : []
        let x = CAKeyframeAnimation(keyPath: "transform.translation.x")
        let y = CAKeyframeAnimation(keyPath: "transform.translation.y")
        (x.values, y.values) = ([0] + (offsets + rest).map(\.x), [0] + (offsets + rest).map(\.y))
        let times = (0...offsets.count).map { NSNumber(value: Double($0) * level.jolt / duration) } + (rest.isEmpty ? [] : [1])
        (x.keyTimes, y.keyTimes) = (times, times)
        let group = CAAnimationGroup()
        group.animations = [x, y]
        group.duration = duration
        group.repeatCount = .infinity
        for target in targets { target.add(group, forKey: "shake") }
        if level == .topiramate { throb([layers.signEdge, layers.sign, layers.signText]) }
    }

    static func throb(_ layers: [CALayer]) {
        for layer in layers {
            let throb = CABasicAnimation(keyPath: "transform.scale")
            throb.fromValue = 0
            throb.toValue = 0.07
            throb.duration = 0.09
            throb.autoreverses = true
            throb.repeatCount = .infinity
            throb.isAdditive = true
            layer.add(throb, forKey: "throb")
        }
    }
}
