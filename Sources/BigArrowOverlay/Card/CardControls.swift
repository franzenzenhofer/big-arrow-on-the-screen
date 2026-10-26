import AppKit
import BigArrowCore

/// What the human does on a card, handed to whoever runs it.
@MainActor
public final class CardEvents {
    /// A copy button: the row and the value to put on the clipboard (a TOTP row's current code).
    public var copy: (CardRow, String) -> Void = { _, _ in }
    /// A link opened.
    public var open: (String) -> Void = { _ in }
    /// The card is answered: the outcome and its value (button id, option id, typed text).
    public var answer: (CardOutcome, String?) -> Void = { _, _ in }
    /// The X button or Esc.
    public var close: () -> Void = {}
    /// A row (or checklist item) with a `point` became the one the human is working on.
    public var activate: (CardPoint, String) -> Void = { _, _ in }
    /// Checklist ticks and typed text, as they change.
    public var checked: ([String]) -> Void = { _ in }
    public var typed: (String, String) -> Void = { _, _ in }

    public init() {}
}

/// A borderless button that runs a closure and takes the first click, so it works while the
/// card's panel is not key and the human's app stays active.
@MainActor
final class ActionButton: NSButton {
    var handler: () -> Void = {}

    convenience init(icon: FeatherIcon, tint: NSColor, tooltip: String, handler: @escaping () -> Void) {
        self.init(frame: .zero)
        image = CardStyle.icon(icon)
        imagePosition = .imageOnly
        isBordered = false
        contentTintColor = tint
        toolTip = tooltip
        setAccessibilityLabel(tooltip)
        self.handler = handler
        target = self
        action = #selector(run)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: CardStyle.iconButton),
            heightAnchor.constraint(equalToConstant: CardStyle.iconButton)
        ])
    }

    /// Swaps the icon for a moment, e.g. copy to check.
    func flash(_ icon: FeatherIcon, back original: FeatherIcon) {
        image = CardStyle.icon(icon)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            MainActor.assumeIsolated { self?.image = CardStyle.icon(original) }
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc func run() {
        handler()
    }
}

/// A text button: `primary` filled in the card colour, otherwise outlined.
@MainActor
final class PillButton: NSButton {
    var handler: () -> Void = {}

    convenience init(_ title: String, primary: Bool, style: CardStyle, handler: @escaping () -> Void) {
        self.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = primary ? 0 : 2
        layer?.borderColor = style.tint.cgColor
        layer?.backgroundColor = primary ? style.tint.cgColor : NSColor.clear.cgColor
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: CardStyle.buttonFont, .foregroundColor: primary ? style.onTint : style.tint
        ])
        setAccessibilityLabel(title)
        self.handler = handler
        target = self
        action = #selector(run)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: 42).isActive = true
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width + 32, height: max(size.height + 16, 42))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc func run() {
        handler()
    }
}

/// Stacks views vertically or horizontally with the card's spacing.
@MainActor
enum Stack {
    static func vertical(_ views: [NSView], spacing: CGFloat = 6) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    static func horizontal(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = spacing
        return stack
    }
}
