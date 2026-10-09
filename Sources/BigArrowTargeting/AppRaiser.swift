import AppKit
import ApplicationServices
import BigArrowCore

/// Brings an app, and optionally one of its windows, to the front so the arrow points at
/// something the human can see. Activating needs no permission; raising one particular window
/// of the app (by title) uses Accessibility.
@MainActor
public enum AppRaiser {
    public struct Raised: Codable, Sendable {
        public let app: String
        public let pid: Int32
        public let frontmost: Bool
        public let window: String?
    }

    static let settleTimeout: TimeInterval = 1.5
    static let pollStep: TimeInterval = 0.05

    public static func raise(app query: String, windowTitle: String?, screens: ScreenSpace) throws -> Raised {
        let running = try ElementTarget.application(named: query, screens: screens)
        running.unhide()
        var raisedWindow: String?
        if let windowTitle {
            try Permission.accessibility.require(for: "Raising a window by title")
            raisedWindow = try raiseWindow(pid: running.processIdentifier, title: windowTitle)
        }
        running.activate()
        let frontmost = waitUntilFrontmost(running)
        guard frontmost else {
            throw BigArrowError.unresolvable("\(running.localizedName ?? query) did not come to the front within \(settleTimeout) s")
        }
        return Raised(app: running.localizedName ?? query, pid: running.processIdentifier, frontmost: frontmost, window: raisedWindow)
    }

    /// Spins the run loop until the app is frontmost and its windows have been reordered.
    static func waitUntilFrontmost(_ app: NSRunningApplication) -> Bool {
        let deadline = Date().addingTimeInterval(settleTimeout)
        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
                RunLoop.main.run(until: Date().addingTimeInterval(pollStep * 2))
                return true
            }
            RunLoop.main.run(until: Date().addingTimeInterval(pollStep))
        }
        return false
    }

    /// Unminimizes and raises the first window whose title contains `title`, and makes it main.
    /// No window title matches: selects the tab with that title (Chrome, Safari) and raises its window.
    static func raiseWindow(pid: pid_t, title: String) throws -> String {
        let app = AXUIElementCreateApplication(pid)
        let windows: [AXUIElement] = TabSelector.attribute(app, kAXWindowsAttribute) ?? []
        let needle = title.lowercased()
        let window = windows.first { windowTitle($0)?.lowercased().contains(needle) ?? false }
            ?? TabSelector.select(in: windows, title: title)
        guard let window else {
            throw BigArrowError.unresolvable("no window or tab of pid \(pid) has a title containing '\(title)'")
        }
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        return windowTitle(window) ?? title
    }

    static func windowTitle(_ window: AXUIElement) -> String? {
        TabSelector.attribute(window, kAXTitleAttribute)
    }
}
