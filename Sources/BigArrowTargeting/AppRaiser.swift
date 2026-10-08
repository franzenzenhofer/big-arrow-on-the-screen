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

    public static func raise(app query: String, windowTitle: String?) throws -> Raised {
        let running = try ElementTarget.application(named: query)
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
    static func raiseWindow(pid: pid_t, title: String) throws -> String {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        let windows = value as? [AXUIElement] ?? []
        let needle = title.lowercased()
        for window in windows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            guard let windowTitle = titleValue as? String, windowTitle.lowercased().contains(needle) else { continue }
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            return windowTitle
        }
        throw BigArrowError.unresolvable("no window of pid \(pid) has a title containing '\(title)'")
    }
}
