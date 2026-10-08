import Foundation
import CoreGraphics

/// What the arrow points at, in global top-left points.
public enum TargetShape: Equatable, Sendable {
    case point(CGPoint)
    case rect(CGRect)

    public var anchor: CGPoint {
        switch self {
        case .point(let point): point
        case .rect(let rect): rect.center
        }
    }

    public var rect: CGRect? {
        if case .rect(let rect) = self { return rect }
        return nil
    }
}

/// A resolved target plus where it came from, for `--json` output.
public struct ResolvedTarget: Equatable, Sendable {
    public let shape: TargetShape
    public let source: String
    public let detail: [String: String]

    public init(shape: TargetShape, source: String, detail: [String: String] = [:]) {
        self.shape = shape
        self.source = source
        self.detail = detail
    }
}

/// Parses the CLI's comma-separated numbers.
public enum NumberListParser {
    public static func point(_ raw: String) throws -> CGPoint {
        let values = try numbers(raw, count: 2, example: "760,500")
        return CGPoint(x: values[0], y: values[1])
    }

    public static func rect(_ raw: String) throws -> CGRect {
        let values = try numbers(raw, count: 4, example: "400,300,200,80")
        guard values[2] > 0, values[3] > 0 else {
            throw BigArrowError.badInput("rect '\(raw)' needs a positive width and height")
        }
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    private static func numbers(_ raw: String, count: Int, example: String) throws -> [CGFloat] {
        let parts = raw.split(separator: ",", omittingEmptySubsequences: false)
        let values = parts.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == count, values.count == count, values.allSatisfy(\.isFinite) else {
            throw BigArrowError.badInput("'\(raw)' is not \(count) comma-separated numbers, example: \(example)")
        }
        return values.map { CGFloat($0) }
    }
}
