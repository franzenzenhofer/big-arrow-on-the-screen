import CoreGraphics

/// Where the sign sits relative to the target. The arrow approaches from that side.
public enum ApproachDirection: String, CaseIterable, Sendable, Codable {
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    case left
    case right
    case top
    case bottom

    /// Unit vector from the target towards the sign, y-down.
    public var unit: CGPoint {
        switch self {
        case .topLeft: CGPoint(x: -1, y: -1).normalized
        case .topRight: CGPoint(x: 1, y: -1).normalized
        case .bottomLeft: CGPoint(x: -1, y: 1).normalized
        case .bottomRight: CGPoint(x: 1, y: 1).normalized
        case .left: CGPoint(x: -1, y: 0)
        case .right: CGPoint(x: 1, y: 0)
        case .top: CGPoint(x: 0, y: -1)
        case .bottom: CGPoint(x: 0, y: 1)
        }
    }

    public static func parse(_ raw: String) throws -> ApproachDirection? {
        let key = raw.lowercased()
        if key == "auto" { return nil }
        guard let direction = ApproachDirection(rawValue: key) else {
            let names = (["auto"] + allCases.map(\.rawValue)).joined(separator: ", ")
            throw BigArrowError.badInput("--from '\(raw)' is not one of \(names)")
        }
        return direction
    }
}

/// Chooses the sign position with the most free space. Pure and deterministic.
public enum Placement {
    /// Side of the square zone around the target the sign never covers.
    public static let keepOutSide: CGFloat = 120
    /// Gap between the sign and the edge of the usable area.
    public static let margin: CGFloat = 16
    static let reachScales: [CGFloat] = [1.0, 0.75, 1.4, 0.55, 1.9, 2.5]
    /// Score cost per unit of reach change: a cramped or overlong arrow only wins when the
    /// preferred length does not fit.
    static let shortcutPenalty: CGFloat = 400

    public struct Result: Equatable, Sendable {
        public let direction: ApproachDirection
        public let signRect: CGRect
        public let keepOut: CGRect
    }

    /// All rects are display-local top-left points. `area` is the usable part of the display.
    public static func place(
        sign size: CGSize,
        around marked: CGRect,
        in area: CGRect,
        reach: CGFloat,
        forced: ApproachDirection? = nil,
        avoiding others: [CGRect] = []
    ) -> Result {
        let situation = Situation(
            size: size, keepOut: keepOutZone(around: marked), usable: area.insetBy(dx: margin, dy: margin), reach: reach,
            others: others.map { $0.insetBy(dx: -otherGap, dy: -otherGap) }
        )
        let directions = ApproachDirection.allCases
        // A forced side is a preference: if the sign does not fit there, the roomiest other side
        // wins, because an arrow must never hide what it points at. Other arrows' signs are
        // avoided while that is possible, and ignored only when nothing else fits.
        let attempts: [(Situation, [ApproachDirection])] = [
            (situation, forced.map { [$0] } ?? []), (situation, directions),
            (situation.toleratingOthers, forced.map { [$0] } ?? []), (situation.toleratingOthers, directions)
        ]
        for (context, sides) in attempts where !sides.isEmpty {
            if let result = best(context, directions: sides) { return result }
        }
        let candidates = directions.map {
            signRect(size: size, keepOut: situation.keepOut, direction: $0, reach: reach)
        }
        return fallbackClamped(candidates, directions: directions, keepOut: situation.keepOut, usable: situation.usable)
    }

    /// Space kept between this sign and the signs of other live arrows.
    public static let otherGap: CGFloat = 12

    /// How other arrows' signs count: never overlap them, or overlap them as little as possible.
    enum OthersPolicy {
        case avoid
        case minimizeOverlap
    }

    /// Score cost per square point of overlap with another sign, when overlap cannot be avoided.
    static let overlapPenalty: CGFloat = 0.05

    /// What every candidate is judged against.
    struct Situation {
        let size: CGSize
        let keepOut: CGRect
        let usable: CGRect
        let reach: CGFloat
        let others: [CGRect]
        var policy = OthersPolicy.avoid

        var toleratingOthers: Situation {
            var copy = self
            copy.policy = .minimizeOverlap
            return copy
        }

        func overlap(_ rect: CGRect) -> CGFloat {
            others.reduce(0) { total, other in
                let shared = rect.intersection(other)
                return shared.isNull ? total : total + shared.width * shared.height
            }
        }
    }

    /// The best-scoring sign that fits fully and clears the keep-out zone, if any.
    static func best(_ situation: Situation, directions: [ApproachDirection]) -> Result? {
        let (size, keepOut, usable, reach) = (situation.size, situation.keepOut, situation.usable, situation.reach)
        var best: (score: CGFloat, result: Result)?
        for (rank, direction) in directions.enumerated() {
            for scale in reachScales {
                let rect = signRect(size: size, keepOut: keepOut, direction: direction, reach: reach * scale)
                let overlap = situation.overlap(rect)
                guard usable.contains(rect), !rect.intersects(keepOut),
                      situation.policy == .minimizeOverlap || overlap == 0 else { continue }
                let score = clearance(of: rect, in: usable) - abs(scale - 1) * Self.shortcutPenalty - CGFloat(rank) * 4
                    - overlap * Self.overlapPenalty
                if score > best?.score ?? -.infinity {
                    best = (score, Result(direction: direction, signRect: rect, keepOut: keepOut))
                }
            }
        }
        return best?.result
    }

    /// The square keep-out zone, grown to cover the marked rect.
    public static func keepOutZone(around marked: CGRect) -> CGRect {
        let square = CGRect(
            x: marked.midX - keepOutSide / 2, y: marked.midY - keepOutSide / 2,
            width: keepOutSide, height: keepOutSide
        )
        return square.union(marked.insetBy(dx: -12, dy: -12))
    }

    static func signRect(size: CGSize, keepOut: CGRect, direction: ApproachDirection, reach: CGFloat) -> CGRect {
        let unit = direction.unit
        let distance = support(keepOut.size, unit) + reach + support(size, unit)
        let center = keepOut.center + unit * distance
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// Half extent of a rect of `size` along `unit`, the rect's support function.
    static func support(_ size: CGSize, _ unit: CGPoint) -> CGFloat {
        abs(unit.x) * size.width / 2 + abs(unit.y) * size.height / 2
    }

    static func clearance(of rect: CGRect, in area: CGRect) -> CGFloat {
        min(min(rect.minX - area.minX, area.maxX - rect.maxX), min(rect.minY - area.minY, area.maxY - rect.maxY), 200)
    }

    /// No candidate fits cleanly (tiny display or huge sign): keep the sign on screen, overlap least.
    static func fallbackClamped(
        _ rects: [CGRect], directions: [ApproachDirection], keepOut: CGRect, usable: CGRect
    ) -> Result {
        var best: (overlap: CGFloat, result: Result)?
        for (rect, direction) in zip(rects, directions) {
            let clamped = rect.clamped(into: usable)
            let overlap = clamped.intersection(keepOut)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area < best?.overlap ?? .infinity {
                best = (area, Result(direction: direction, signRect: clamped, keepOut: keepOut))
            }
        }
        guard let best else { preconditionFailure("placement needs at least one direction") }
        return best.result
    }
}
