import AppKit
import BigArrowCore

/// Owns the overlay panel for one arrow: show, move (for --follow), hide, dismiss.
@MainActor
public final class OverlayController {
    private var panel: OverlayPanel?
    private var layers: OverlayLayers?
    private(set) public var layout: OverlayLayout?
    private let mode: AnimationMode
    private let color: ArrowColor
    private var closeButton: CloseButtonPanel?

    /// Adds the clickable X to the sign; `onClose` runs when the human clicks it.
    public func enableCloseButton(onClose: @escaping @MainActor () -> Void) {
        closeButton = CloseButtonPanel(color: color, onClose: onClose)
    }

    public init(mode: AnimationMode, color: ArrowColor) {
        self.mode = mode
        self.color = color
    }

    /// Shows the layout on its display. The panel is reused while the display stays the same.
    public func show(_ layout: OverlayLayout, sign: SignImage, animated: Bool) throws {
        guard let screen = ScreenReader.screen(for: layout.display) else {
            throw BigArrowError.unresolvable("display \(layout.display.index + 1) is no longer connected")
        }
        if panel == nil || self.layout?.display != layout.display {
            panel?.orderOut(nil)
            panel = OverlayPanel(screen: screen)
        }
        let layers = OverlayLayers(layout: layout, sign: sign, color: color)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel?.contentView?.layer?.sublayers = [layers.root]
        CATransaction.commit()
        if animated { Animator.enter(layers, mode: mode) }
        self.layers = layers
        self.layout = layout
        panel?.orderFrontRegardless()
        if let closeButton {
            closeButton.place(onSign: Self.appKitRect(layout.signRect, on: layout.display))
            closeButton.orderFrontRegardless()
        }
    }

    /// Display-local top-left rect to AppKit screen coordinates (bottom-left of the primary display).
    static func appKitRect(_ local: CGRect, on display: Display) -> CGRect {
        let global = local.offsetBy(dx: display.frame.minX, dy: display.frame.minY)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return ScreenSpace.flip(global, primaryHeight: primaryHeight)
    }

    /// Hides without ending, used while a followed target is gone.
    public func hide() {
        panel?.orderOut(nil)
        closeButton?.orderOut(nil)
    }

    public func unhide() {
        panel?.orderFrontRegardless()
        closeButton?.orderFrontRegardless()
    }

    /// The window-server number of the panel, for `--json` and tests.
    public var windowNumber: Int? { panel?.windowNumber }

    /// Fades out, closes the panel, then calls `completion`.
    public func dismiss(completion: @escaping @MainActor () -> Void) {
        closeButton?.orderOut(nil)
        guard let root = layers?.root, mode.fadeOut > 0, panel?.isVisible == true else {
            close()
            completion()
            return
        }
        Animator.fade(root, from: root.presentation()?.opacity ?? 1, to: 0, duration: mode.fadeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + mode.fadeOut) {
            MainActor.assumeIsolated {
                self.close()
                completion()
            }
        }
    }

    private func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}
