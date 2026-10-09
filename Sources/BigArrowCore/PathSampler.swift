import CoreGraphics
import Foundation

/// Evenly spaced points along a path, for effects that follow the shaft (drips, flames),
/// whatever its shape: bend, straight, zigzag or spiral.
public enum PathSampler {
    /// Steps per curve element when flattening it into lines.
    static let curveSteps = 24

    /// A spot on the path: where, which way the path runs there, and how far along it is (0...1).
    public struct Sample: Sendable, Equatable {
        public let point: CGPoint
        public let tangent: CGPoint
        public let share: CGFloat
    }

    /// A sample every `spacing` points of length, starting `spacing / 2` in.
    public static func samples(along path: CGPath, spacing: CGFloat) -> [Sample] {
        let line = flattened(path)
        let total = zip(line, line.dropFirst()).reduce(CGFloat(0)) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
        guard spacing > 0, total > 0 else { return [] }
        var result: [Sample] = []
        var next = spacing / 2
        var travelled: CGFloat = 0
        for (from, to) in zip(line, line.dropFirst()) {
            let length = hypot(to.x - from.x, to.y - from.y)
            let tangent = length > 0 ? CGPoint(x: (to.x - from.x) / length, y: (to.y - from.y) / length) : .zero
            while length > 0, next <= travelled + length {
                let share = (next - travelled) / length
                let point = CGPoint(x: from.x + (to.x - from.x) * share, y: from.y + (to.y - from.y) * share)
                result.append(Sample(point: point, tangent: tangent, share: next / total))
                next += spacing
            }
            travelled += length
        }
        return result
    }

    /// The path as one polyline; curves are split into `curveSteps` lines.
    public static func flattened(_ path: CGPath) -> [CGPoint] {
        var points: [CGPoint] = []
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            let last = points.last ?? .zero
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.points[0])
            case .addQuadCurveToPoint:
                let (control, end) = (element.points[0], element.points[1])
                points += steps { t in quad(last, control, end, t) }
            case .addCurveToPoint:
                let (first, second, end) = (element.points[0], element.points[1], element.points[2])
                points += steps { t in cubic([last, first, second, end], t) }
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        return points
    }

    static func steps(_ point: (CGFloat) -> CGPoint) -> [CGPoint] {
        (1...curveSteps).map { point(CGFloat($0) / CGFloat(curveSteps)) }
    }

    static func quad(_ start: CGPoint, _ control: CGPoint, _ end: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
            y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
        )
    }

    static func cubic(_ points: [CGPoint], _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let weights = [u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t]
        return zip(points, weights).reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.0.x * $1.1, y: $0.y + $1.0.y * $1.1) }
    }

    /// A repeatable value in 0..<1 for index `i`, so effects look random but every render is the same.
    public static func jitter(_ i: Int, salt: Int) -> CGFloat {
        let value = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
        return CGFloat(value - floor(value))
    }
}
