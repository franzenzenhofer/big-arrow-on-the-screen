import CoreGraphics

/// `--shake`: how upset the arrow is. The whole arrow vibrates, a random jolt every few hundredths of a second.
public enum ShakeLevel: Int, CaseIterable, Sendable {
    case mild = 1
    case insistent = 2
    case angry = 3
    case topiramate = 4

    public var name: String {
        switch self {
        case .mild: "mild"
        case .insistent: "insistent"
        case .angry: "angry"
        case .topiramate: "topiramate"
        }
    }

    /// Largest jolt away from the resting place, in points.
    public var amplitude: CGFloat {
        switch self {
        case .mild: 2
        case .insistent: 4
        case .angry: 7
        case .topiramate: 13
        }
    }

    /// Seconds per jolt.
    public var jolt: Double {
        switch self {
        case .mild: 0.06
        case .insistent: 0.045
        case .angry: 0.035
        case .topiramate: 0.025
        }
    }

    /// Seconds from one burst to the next; 0: it never rests.
    public var period: Double {
        switch self {
        case .mild: 2.5
        case .insistent: 1.2
        case .angry, .topiramate: 0
        }
    }

    public static func parse(_ raw: String) throws -> ShakeLevel {
        let key = raw.lowercased().trimmingCharacters(in: .whitespaces)
        if let level = Int(key).flatMap(ShakeLevel.init(rawValue:)) ?? allCases.first(where: { $0.name == key }) {
            return level
        }
        let names = allCases.map { "\($0.rawValue) (\($0.name))" }.joined(separator: ", ")
        throw BigArrowError.badInput("shake '\(raw)' is not one of \(names)")
    }
}

/// `--rainbow`, `--drip`, `--flames` and `--shake`. All off by default.
public struct ArrowEffects: Sendable, Equatable {
    public var rainbow = false
    public var drip = false
    public var flames = false
    public var shake: ShakeLevel?

    public init() {}

    public var isEmpty: Bool { self == ArrowEffects() }
}
