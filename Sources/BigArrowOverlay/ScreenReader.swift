import AppKit
import BigArrowCore

/// Reads the live display list from AppKit and converts it to top-left global points.
@MainActor
public enum ScreenReader {
    public static func current() -> ScreenSpace {
        ScreenSpace.fromAppKit(NSScreen.screens.map(appKitScreen))
    }

    public static func screen(for display: Display) -> NSScreen? {
        NSScreen.screens.first { displayID(of: $0) == display.id }
    }

    static func appKitScreen(_ screen: NSScreen) -> AppKitScreen {
        AppKitScreen(
            id: displayID(of: screen), frame: screen.frame,
            visibleFrame: screen.visibleFrame, scale: screen.backingScaleFactor
        )
    }

    static func displayID(of screen: NSScreen) -> UInt32 {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.uint32Value ?? 0
    }

    /// The mouse position in global top-left points.
    public static func mouseLocation() -> CGPoint {
        let height = NSScreen.screens.first?.frame.height ?? 0
        return ScreenSpace.flip(NSEvent.mouseLocation, primaryHeight: height)
    }
}
