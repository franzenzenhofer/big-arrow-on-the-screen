import AppKit
import BigArrowCore

/// The whole card: the header in the card colour (title and X), then the rows on the system's
/// window background, light or dark. Taller than the screen allows, the rows scroll.
@MainActor
public final class CardView: NSView {
    public let document: CardDocument
    let style: CardStyle
    let events: CardEvents
    private(set) var rows: [RowContainer] = []

    public init(document: CardDocument, color: ArrowColor, events: CardEvents, maxHeight: CGFloat) throws {
        self.document = document
        self.style = CardStyle(color: color)
        self.events = events
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = CardStyle.corner
        layer?.masksToBounds = true
        layer?.borderWidth = CardStyle.border
        layer?.borderColor = style.tint.cgColor
        rows = try document.rows.map { row in
            RowContainer(row: row, content: try RowFactory.view(for: row, style: style, events: events), style: style, events: events)
        }
        try build(maxHeight: maxHeight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    func build(maxHeight: CGFloat) throws {
        let header = CardHeader(title: document.title, style: style) { [events] in events.close() }
        let body = Stack.vertical(rows, spacing: CardStyle.rowSpacing)
        body.edgeInsets = NSEdgeInsets(top: 18, left: 0, bottom: 20, right: 0)
        rows.forEach { $0.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true }
        let content = Stack.vertical([header, scrolling(body, maxHeight: maxHeight - header.fittingSize.height)], spacing: 0)
        content.arrangedSubviews.forEach { $0.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
        RowLayout.fill(self, with: content)
        widthAnchor.constraint(equalToConstant: CardStyle.width).isActive = true
    }

    /// The rows as they are, or in a scroll view when they are taller than `maxHeight`.
    func scrolling(_ body: NSStackView, maxHeight: CGFloat) -> NSView {
        body.translatesAutoresizingMaskIntoConstraints = false
        body.widthAnchor.constraint(equalToConstant: CardStyle.width).isActive = true
        let height = body.fittingSize.height
        guard height > maxHeight else { return body }
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = body
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: max(120, maxHeight)).isActive = true
        return scroll
    }

    /// Marks the row (or the checklist holding the item) the arrow points from.
    public func markActive(_ name: String?) {
        for row in rows { row.setActive(name != nil && row.names.contains(name ?? "")) }
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }

    public override func layout() {
        super.layout()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }
}

/// The card colour band with the title and the X button.
@MainActor
final class CardHeader: NSView {
    static let spacing: CGFloat = 10
    static let trailing: CGFloat = 14

    init(title: String, style: CardStyle, close: @escaping () -> Void) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = style.tint.cgColor
        // Room left of the X: side insets, the X, and the stack's spacing on both sides of the spacer.
        let width = CardStyle.width - CardStyle.padding - Self.trailing - CardStyle.iconButton - Self.spacing * 2
        let label = CardStyle.label(title, font: CardStyle.titleFont, color: style.onTint, width: width)
        let button = ActionButton(icon: .close, tint: style.tint, tooltip: "Close") { close() }
        button.wantsLayer = true
        button.layer?.cornerRadius = CardStyle.iconButton / 2
        button.layer?.backgroundColor = style.onTint.cgColor
        let line = Stack.horizontal([label, NSView(), button], spacing: Self.spacing)
        line.alignment = .top
        line.edgeInsets = NSEdgeInsets(top: 16, left: CardStyle.padding, bottom: 16, right: Self.trailing)
        RowLayout.fill(self, with: line)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }
}

/// One row with the card's side padding and an accent bar while its arrow is shown. A click on a
/// row that points somewhere shows that arrow.
@MainActor
final class RowContainer: NSView {
    let row: CardRow
    let events: CardEvents
    let accent = NSView()

    init(row: CardRow, content: NSView, style: CardStyle, events: CardEvents) {
        self.row = row
        self.events = events
        super.init(frame: .zero)
        accent.wantsLayer = true
        accent.layer?.backgroundColor = style.tint.cgColor
        accent.layer?.cornerRadius = CardStyle.accentWidth / 2
        accent.isHidden = true
        RowLayout.fill(self, with: content, horizontal: CardStyle.padding)
        accent.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accent)
        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            accent.widthAnchor.constraint(equalToConstant: CardStyle.accentWidth),
            accent.topAnchor.constraint(equalTo: topAnchor),
            accent.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    /// The row's own name and its checklist items' labels, as `activate` names them.
    var names: [String] { [row.name] + (row.items ?? []).map(\.label) }

    func setActive(_ active: Bool) {
        accent.isHidden = !active
    }

    override var mouseDownCanMoveWindow: Bool { row.point == nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let point = row.point else { return super.mouseDown(with: event) }
        events.activate(point, row.name)
    }
}
