import Foundation

/// `--border`: how arrow and sign stand off the screen behind them.
public enum ArrowBorder: String, CaseIterable, Sendable {
    /// The default: the contrast border (white on dark arrows) and a drop shadow.
    case shadow
    /// The contrast border with a thin black edge outside it, no shadow.
    case whiteBlack = "white-black"
    /// Only a thin black outline (white on near-black arrows), no shadow.
    case black

    public var hasShadow: Bool { self == .shadow }

    public static func parse(_ raw: String) throws -> ArrowBorder {
        guard let border = ArrowBorder(rawValue: raw.lowercased()) else {
            throw BigArrowError.badInput("border '\(raw)' is not one of \(allCases.map(\.rawValue).joined(separator: ", "))")
        }
        return border
    }
}

/// `--close-button`: an X drawn inside the sign's right end, so it never covers text or leaves the screen.
public enum CloseMark: Sendable, Equatable {
    case none
    case cross
}

/// Everything about how the sign looks, besides its text.
public struct SignAppearance: Sendable {
    public let color: ArrowColor
    public let size: ArrowSize
    public let corners: SignCorners
    public var border = ArrowBorder.shadow
    public var closeMark = CloseMark.none
    public var effects = ArrowEffects()
    /// `--border-color`, `--text-color`, `--edge-color`; nil picks a readable colour automatically.
    public var borderColor: ArrowColor?
    public var textColor: ArrowColor?
    public var edgeColor: ArrowColor?

    /// The border: white on dark arrows, dark on light ones, unless set.
    public var borderTint: ArrowColor { borderColor ?? color.contrast }
    public var textTint: ArrowColor { textColor ?? color.contrast }
    /// The thin line: black (white for `--border black` on near-black arrows), unless set.
    public var edgeTint: ArrowColor { edgeColor ?? (border == .black ? color.outline : .black) }
    /// `--close-color` and `--close-x-color` for the X button.
    public var closeColor: ArrowColor?
    public var closeXColor: ArrowColor?
    /// The X button's circle: the border colour (white on dark arrows), unless set.
    public var closeTint: ArrowColor { closeColor ?? borderTint }
    /// The X: the arrow colour on the default circle, else whatever reads on the chosen circle.
    public var closeXTint: ArrowColor { closeXColor ?? (closeColor == nil ? color : closeTint.contrast) }

    public init(color: ArrowColor, size: ArrowSize, corners: SignCorners) {
        self.color = color
        self.size = size
        self.corners = corners
    }
}
