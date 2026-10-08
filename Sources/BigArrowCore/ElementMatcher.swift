import CoreGraphics
import Foundation

/// The attributes of one Accessibility element that matching needs. Codable so a live
/// AX walk can be recorded as a fixture.
public struct AXNodeInfo: Codable, Equatable, Sendable {
    public let role: String?
    public let title: String?
    public let label: String?
    public let value: String?
    public let identifier: String?
    /// Global top-left points, straight from kAXPosition and kAXSize.
    public let frame: CGRect?
    public let enabled: Bool?

    public init(
        role: String?, title: String?, label: String?, value: String?,
        identifier: String?, frame: CGRect?, enabled: Bool?
    ) {
        self.role = role
        self.title = title
        self.label = label
        self.value = value
        self.identifier = identifier
        self.frame = frame
        self.enabled = enabled
    }

    public var texts: [String] { [title, label, value, identifier].compactMap { $0?.lowercased() } }
}

/// `--element 'Save' [--role button]`.
public struct ElementQuery: Equatable, Sendable {
    public let text: String
    public let role: String?

    public init(text: String, role: String?) throws {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw BigArrowError.badInput("--element needs a label, example: --element 'Reload'")
        }
        self.text = text
        self.role = role.map(Self.normalizedRole)
    }

    /// `AXButton`, `button` and `Button` are the same role.
    public static func normalizedRole(_ role: String) -> String {
        let lower = role.lowercased()
        return lower.hasPrefix("ax") ? String(lower.dropFirst(2)) : lower
    }

    /// 3 exact, 2 prefix, 1 substring, 0 no match.
    public func score(_ node: AXNodeInfo) -> Int {
        if let role, ElementQuery.normalizedRole(node.role ?? "") != role { return 0 }
        let needle = text.lowercased()
        let texts = node.texts
        if texts.contains(needle) { return 3 }
        if texts.contains(where: { $0.hasPrefix(needle) }) { return 2 }
        if texts.contains(where: { $0.contains(needle) }) { return 1 }
        return 0
    }
}

/// Ranks matching elements: best text match, then visible, then enabled, then tree order.
public enum ElementMatcher {
    public struct Match: Equatable, Sendable {
        public let node: AXNodeInfo
        public let score: Int
        public let visible: Bool
        public let order: Int
    }

    public static func rank(_ nodes: [AXNodeInfo], query: ElementQuery, displays: [Display]) -> [Match] {
        let matches = nodes.enumerated().compactMap { order, node -> Match? in
            let score = query.score(node)
            guard score > 0 else { return nil }
            return Match(node: node, score: score, visible: isVisible(node, displays), order: order)
        }
        return matches.sorted(by: isBetter)
    }

    static func isBetter(_ lhs: Match, _ rhs: Match) -> Bool {
        if lhs.visible != rhs.visible { return lhs.visible }
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        let lhsEnabled = lhs.node.enabled ?? true
        let rhsEnabled = rhs.node.enabled ?? true
        if lhsEnabled != rhsEnabled { return lhsEnabled }
        return lhs.order < rhs.order
    }

    public static func isVisible(_ node: AXNodeInfo, _ displays: [Display]) -> Bool {
        guard let frame = node.frame, frame.width > 0, frame.height > 0 else { return false }
        return displays.contains { $0.frame.intersects(frame) }
    }
}
