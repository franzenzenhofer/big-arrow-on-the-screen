import ApplicationServices
import BigArrowCore
import Foundation

/// Walks an app's Accessibility tree breadth first, windows before the menu bar,
/// within a depth limit, a node limit and a time budget.
public struct AXWalker {
    public static let maxDepth = 25
    public static let maxNodes = 20_000
    public static let budget: TimeInterval = 2
    static let messagingTimeout: Float = 0.5

    static let attributes: [String] = [
        kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute,
        kAXIdentifierAttribute, kAXPositionAttribute, kAXSizeAttribute, kAXEnabledAttribute,
        kAXChildrenAttribute
    ]

    let pid: pid_t

    public init(pid: pid_t) {
        self.pid = pid
    }

    /// Chromium and Electron build the Accessibility tree of web content only on request.
    static let manualAccessibility = "AXManualAccessibility"
    /// Time Chromium needs to build that tree after the first request.
    static let webTreeDelay: TimeInterval = 0.6

    /// Flattened nodes in breadth-first order. Stops early when `stop` returns true.
    public func walk(stop: (AXNodeInfo) -> Bool = { _ in false }) -> [AXNodeInfo] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)
        requestWebContentTree(app)
        var queue: [(AXUIElement, Int)] = roots(of: app).map { ($0, 0) }
        var nodes: [AXNodeInfo] = []
        let deadline = Date().addingTimeInterval(Self.budget)
        var index = 0
        while index < queue.count, nodes.count < Self.maxNodes, Date() < deadline {
            let (element, depth) = queue[index]
            index += 1
            let (node, children) = read(element)
            nodes.append(node)
            if stop(node) { break }
            if depth < Self.maxDepth { queue.append(contentsOf: children.map { ($0, depth + 1) }) }
        }
        return nodes
    }

    /// Asks a Chromium or Electron app for its web content tree; other apps ignore the attribute.
    /// The first request waits briefly so the tree exists before the walk.
    func requestWebContentTree(_ app: AXUIElement) {
        let enabled: Bool? = copy(app, Self.manualAccessibility)
        guard enabled != true else { return }
        let result = AXUIElementSetAttributeValue(app, Self.manualAccessibility as CFString, kCFBooleanTrue)
        if result == .success { Thread.sleep(forTimeInterval: Self.webTreeDelay) }
    }

    /// Focused window first, then the other windows, then the menu bar.
    func roots(of app: AXUIElement) -> [AXUIElement] {
        let focused: AXUIElement? = copy(app, kAXFocusedWindowAttribute)
        let windows: [AXUIElement] = copy(app, kAXWindowsAttribute) ?? []
        let menuBar: AXUIElement? = copy(app, kAXMenuBarAttribute)
        var roots = focused.map { [$0] } ?? []
        roots += windows.filter { window in !roots.contains { CFEqual($0, window) } }
        return roots + (menuBar.map { [$0] } ?? [])
    }

    func read(_ element: AXUIElement) -> (AXNodeInfo, [AXUIElement]) {
        var values: CFArray?
        AXUIElementCopyMultipleAttributeValues(element, Self.attributes as CFArray, [], &values)
        let list = (values as? [Any]) ?? []
        func value(_ index: Int) -> Any? {
            guard index < list.count else { return nil }
            let item = list[index] as CFTypeRef
            return Self.isAXError(item) ? nil : list[index]
        }
        let node = AXNodeInfo(
            role: value(0) as? String, title: value(1) as? String, label: value(2) as? String,
            value: value(3) as? String, identifier: value(4) as? String,
            frame: frame(position: value(5), size: value(6)), enabled: value(7) as? Bool
        )
        return (node, value(8) as? [AXUIElement] ?? [])
    }

    func frame(position: Any?, size: Any?) -> CGRect? {
        guard let position, let size,
              CFGetTypeID(position as CFTypeRef) == AXValueGetTypeID(),
              CFGetTypeID(size as CFTypeRef) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(Self.axValue(position), .cgPoint, &point),
              AXValueGetValue(Self.axValue(size), .cgSize, &extent) else { return nil }
        return CGRect(origin: point, size: extent)
    }

    /// Attributes an element does not have come back as an AXValue of type `.axError`.
    static func isAXError(_ item: CFTypeRef) -> Bool {
        CFGetTypeID(item) == AXValueGetTypeID() && AXValueGetType(axValue(item)) == .axError
    }

    /// CoreFoundation types cannot be cast conditionally (`as?` always succeeds), so callers
    /// check `CFGetTypeID` first and this cast is then safe.
    static func axValue(_ item: Any) -> AXValue {
        // swiftlint:disable:next force_cast
        item as! AXValue
    }

    func copy<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
