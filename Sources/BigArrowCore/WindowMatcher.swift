import CoreGraphics
import Foundation

/// A running application as `NSWorkspace` reports it.
public struct RunningAppInfo: Codable, Equatable, Sendable {
    public let pid: Int32
    public let name: String?
    public let bundleID: String?

    public init(pid: Int32, name: String?, bundleID: String?) {
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
    }
}

/// One on-screen window as `CGWindowListCopyWindowInfo` reports it, in list (front to back) order.
public struct WindowInfo: Codable, Equatable, Sendable {
    public let ownerPID: Int32
    public let layer: Int
    public let bounds: CGRect
    public let alpha: Double
    /// Only present with Screen Recording on macOS 26.
    public let title: String?

    public init(ownerPID: Int32, layer: Int, bounds: CGRect, alpha: Double, title: String?) {
        self.ownerPID = ownerPID
        self.layer = layer
        self.bounds = bounds
        self.alpha = alpha
        self.title = title
    }

    /// A normal app window that a human can see.
    public var isVisibleAppWindow: Bool {
        layer == 0 && alpha > 0 && bounds.width >= 40 && bounds.height >= 40
    }
}

/// `--window "App Name[:title substring]"`.
public struct WindowQuery: Equatable, Sendable {
    public let app: String
    public let title: String?

    public init(_ raw: String) throws {
        let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let app = parts[0].trimmingCharacters(in: .whitespaces)
        guard !app.isEmpty else { throw BigArrowError.badInput("--window needs an app name, example: 'Google Chrome'") }
        self.app = app
        let title = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        self.title = title.isEmpty ? nil : title
    }
}

/// Which point inside a window the arrow points at.
public enum WindowAnchor: String, CaseIterable, Sendable {
    case center, title
    case topLeft = "top-left", topRight = "top-right"
    case bottomLeft = "bottom-left", bottomRight = "bottom-right"

    /// Distance from the window edge for the corner anchors and the title bar centre line.
    static let inset: CGFloat = 20
    static let titleBarCenter: CGFloat = 14

    public func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .center: rect.center
        case .title: CGPoint(x: rect.midX, y: rect.minY + Self.titleBarCenter)
        case .topLeft: CGPoint(x: rect.minX + Self.inset, y: rect.minY + Self.inset)
        case .topRight: CGPoint(x: rect.maxX - Self.inset, y: rect.minY + Self.inset)
        case .bottomLeft: CGPoint(x: rect.minX + Self.inset, y: rect.maxY - Self.inset)
        case .bottomRight: CGPoint(x: rect.maxX - Self.inset, y: rect.maxY - Self.inset)
        }
    }

    public static func parse(_ raw: String) throws -> WindowAnchor {
        guard let anchor = WindowAnchor(rawValue: raw.lowercased()) else {
            let names = allCases.map(\.rawValue).joined(separator: ", ")
            throw BigArrowError.badInput("--anchor '\(raw)' is not one of \(names)")
        }
        return anchor
    }
}

/// Matches an app query to running apps and their windows. Pure, fixture-testable.
public enum WindowMatcher {
    /// Exact name or bundle id first, then prefix, then substring. Case-insensitive.
    public static func apps(matching query: String, in apps: [RunningAppInfo]) -> [RunningAppInfo] {
        let needle = query.lowercased()
        let keys: (RunningAppInfo) -> [String] = { [$0.name, $0.bundleID].compactMap { $0?.lowercased() } }
        let tiers: [(String) -> Bool] = [{ $0 == needle }, { $0.hasPrefix(needle) }, { $0.contains(needle) }]
        for tier in tiers {
            let matched = apps.filter { keys($0).contains(where: tier) }
            if !matched.isEmpty { return matched }
        }
        return []
    }

    /// The smallest part of a window, in points per side, that must lie on a display.
    static let minimumVisibleSide: CGFloat = 40

    /// Visible windows of the given pids, front to back, optionally filtered by title substring.
    /// Apps park helper windows off-screen; only windows with a real part on a display count.
    public static func windows(of pids: [Int32], in windows: [WindowInfo], title: String?, displays: [Display]) -> [WindowInfo] {
        windows.filter { window in
            guard pids.contains(window.ownerPID), window.isVisibleAppWindow, isOnScreen(window, displays) else { return false }
            guard let title else { return true }
            return window.title?.lowercased().contains(title.lowercased()) ?? false
        }
    }

    static func isOnScreen(_ window: WindowInfo, _ displays: [Display]) -> Bool {
        displays.contains { display in
            let visible = display.frame.intersection(window.bounds)
            return !visible.isNull && visible.width >= minimumVisibleSide && visible.height >= minimumVisibleSide
        }
    }

    /// Names of apps that have at least one visible window, for the "unknown app" message.
    public static func appsWithWindows(_ apps: [RunningAppInfo], _ windows: [WindowInfo]) -> [String] {
        let pids = Set(windows.filter(\.isVisibleAppWindow).map(\.ownerPID))
        let names = apps.filter { pids.contains($0.pid) }.compactMap(\.name)
        return Array(Set(names)).sorted()
    }
}
