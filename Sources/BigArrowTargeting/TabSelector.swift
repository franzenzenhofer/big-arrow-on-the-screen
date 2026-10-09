import ApplicationServices
import BigArrowCore
import Foundation

/// Finds a tab by title in an app's tab strips and selects it, so `--app "Google Chrome:Inbox"`
/// works for a background tab too. Chrome and Safari expose tabs as AXRadioButton (Chrome:
/// subrole AXTabButton) near the top of the window, so a shallow walk is enough and stays fast.
enum TabSelector {
    static let tabRoles: Set<String> = ["AXRadioButton", "AXTab"]
    static let maxDepth = 10
    static let maxNodes = 4_000
    /// A busy or still-launching app can answer slowly; the search gives up after this.
    static let budget: TimeInterval = 3
    static let messagingTimeout: Float = 0.25

    /// Presses the first tab whose title contains `title` and returns the window it is in.
    static func select(in windows: [AXUIElement], title: String) -> AXUIElement? {
        let needle = title.lowercased()
        let deadline = Date().addingTimeInterval(budget)
        for window in windows {
            guard let tab = findTab(in: window, needle: needle, deadline: deadline) else { continue }
            AXUIElementPerformAction(tab, kAXPressAction as CFString)
            return window
        }
        return nil
    }

    static func findTab(in window: AXUIElement, needle: String, deadline: Date) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(window, 0)]
        var index = 0
        while index < queue.count, index < maxNodes, Date() < deadline {
            let (element, depth) = queue[index]
            index += 1
            AXUIElementSetMessagingTimeout(element, messagingTimeout)
            if let role: String = attribute(element, kAXRoleAttribute), tabRoles.contains(role),
               let name: String = attribute(element, kAXTitleAttribute) ?? attribute(element, kAXDescriptionAttribute),
               name.lowercased().contains(needle) {
                return element
            }
            guard depth < maxDepth else { continue }
            let children: [AXUIElement] = attribute(element, kAXChildrenAttribute) ?? []
            queue.append(contentsOf: children.map { ($0, depth + 1) })
        }
        return nil
    }

    static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
