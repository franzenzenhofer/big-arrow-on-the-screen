import AppKit
import BigArrowCore

/// The clickable X on the sign (`--close-button`). It is the only part of an arrow that takes
/// clicks: a tiny non-activating panel of its own, so the overlay itself stays click-through
/// and clicking the X never activates bigarrow or takes the focus from the human's app.
@MainActor
final class CloseButtonPanel: NSPanel {
    static let side: CGFloat = 44
    /// How far the button's centre sits inside the sign's top-right corner.
    static let inset: CGFloat = 8

    init(color: ArrowColor, onClose: @escaping @MainActor () -> Void) {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: Self.side, height: Self.side),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = CloseButtonView(color: color, onClose: onClose)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Centres the button on the sign's top-right corner. `sign` is in AppKit screen coordinates.
    func place(onSign sign: CGRect) {
        let center = CGPoint(x: sign.maxX - Self.inset, y: sign.maxY - Self.inset)
        setFrameOrigin(CGPoint(x: center.x - Self.side / 2, y: center.y - Self.side / 2))
    }
}

@MainActor
final class CloseButtonView: NSView {
    let color: ArrowColor
    let onClose: @MainActor () -> Void
    static let ring: CGFloat = 3
    static let crossInset: CGFloat = 15
    static let crossWidth: CGFloat = 4

    init(color: ArrowColor, onClose: @escaping @MainActor () -> Void) {
        self.color = color
        self.onClose = onClose
        super.init(frame: CGRect(x: 0, y: 0, width: CloseButtonPanel.side, height: CloseButtonPanel.side))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("CloseButtonView is never loaded from a nib")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClose()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let circle = bounds.insetBy(dx: Self.ring + 2, dy: Self.ring + 2)
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: CGColor(gray: 0, alpha: 0.4))
        context.setFillColor(color.contrast.cgColor)
        context.fillEllipse(in: circle)
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(Self.ring)
        context.strokeEllipse(in: circle)
        let cross = bounds.insetBy(dx: Self.crossInset, dy: Self.crossInset)
        context.setLineWidth(Self.crossWidth)
        context.setLineCap(.round)
        context.strokeLineSegments(between: [
            CGPoint(x: cross.minX, y: cross.minY), CGPoint(x: cross.maxX, y: cross.maxY),
            CGPoint(x: cross.minX, y: cross.maxY), CGPoint(x: cross.maxX, y: cross.minY)
        ])
    }
}
