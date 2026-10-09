import CoreGraphics
import Foundation

/// The shape of the shaft between sign and head.
public enum ArrowShape: String, CaseIterable, Sendable, Codable {
    /// A soft curve (default).
    case bend
    /// A straight line.
    case straight
    /// A lightning-bolt zigzag with rounded joints.
    case zigzag
    /// One loop around the sign, then to the target.
    case spiral

    public static func parse(_ raw: String) throws -> ArrowShape {
        guard let shape = ArrowShape(rawValue: raw.lowercased()) else {
            throw BigArrowError.badInput("shape '\(raw)' is not one of \(allCases.map(\.rawValue).joined(separator: ", "))")
        }
        return shape
    }
}

/// How the shaft is drawn: one quadratic curve (bend, straight) or a polyline (zigzag, spiral).
public enum ShaftLine: Sendable {
    case curve(QuadCurve)
    case polyline([CGPoint])

    public var path: CGPath {
        let path = CGMutablePath()
        switch self {
        case .curve(let curve):
            path.move(to: curve.start)
            path.addQuadCurve(to: curve.end, control: curve.control)
        case .polyline(let points):
            path.addLines(between: points)
        }
        return path
    }
}

/// Builds the zigzag: the chord from the tail to the tip is cut into an odd number of legs; the
/// joints swing alternately left and right, the first leg leaves the sign straight out and the
/// last leg runs into the head.
public enum Zigzag {
    /// Sideways swing of each joint, as a multiple of the stroke.
    static let amplitudeFactor: CGFloat = 2.4
    /// Preferred leg length along the chord.
    static let legLength: CGFloat = 70
    static let minimumLegs = 3
    static let maximumLegs = 7

    /// Joints between the tail and `end`, excluding both. `end` sits a head-length or so before
    /// the tip, so the last leg runs straight into the head.
    public static func joints(tail: CGPoint, end: CGPoint, leaving normal: CGPoint, stroke: CGFloat) -> [CGPoint] {
        let chord = end - tail
        let length = chord.length
        let legs = legCount(for: length)
        let unit = chord.normalized
        let side = unit.perpendicular
        let amplitude = min(stroke * amplitudeFactor, length / CGFloat(legs) * 0.6)
        var joints: [CGPoint] = []
        for index in 1..<legs {
            let along = tail + unit * (length * CGFloat(index) / CGFloat(legs))
            let swing: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            joints.append(along + side * (amplitude * swing))
        }
        if let first = joints.first, (first - tail).dot(normal) < 0 {
            return joints.map { mirror($0, across: tail, unit) }
        }
        return joints
    }

    static func legCount(for length: CGFloat) -> Int {
        let raw = Int((length / legLength).rounded())
        let odd = raw.isMultiple(of: 2) ? raw + 1 : raw
        return min(max(odd, minimumLegs), maximumLegs)
    }

    /// Mirrors a joint to the other side of the chord, so the first leg heads away from the sign.
    static func mirror(_ point: CGPoint, across origin: CGPoint, _ unit: CGPoint) -> CGPoint {
        let relative = point - origin
        let along = unit * relative.dot(unit)
        return origin + along - (relative - along)
    }
}
