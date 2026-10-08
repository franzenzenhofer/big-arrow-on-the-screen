import AppKit
import BigArrowCore

/// Resolves `--element 'Save' [--app Safari] [--role button]` through Accessibility.
/// AX positions and sizes are already global top-left points.
@MainActor
public enum ElementTarget {
    /// Matches reported in `--json` besides the chosen one.
    static let reportedAlternatives = 5

    public static func resolve(_ query: ElementQuery, app: String?, screens: ScreenSpace) throws -> ResolvedTarget {
        try Permission.accessibility.require(for: "Pointing at a UI element (--element)")
        let running = try application(named: app)
        let nodes = AXWalker(pid: running.processIdentifier).walk { node in
            query.score(node) == 3 && ElementMatcher.isVisible(node, screens.displays)
        }
        let matches = ElementMatcher.rank(nodes, query: query, displays: screens.displays)
        let name = running.localizedName ?? app ?? "the frontmost app"
        guard let best = matches.first, best.visible, let frame = best.node.frame else {
            let role = query.role.map { " with role \($0)" } ?? ""
            throw BigArrowError.unresolvable(
                "no visible element labelled '\(query.text)'\(role) in \(name) (searched \(nodes.count) elements)"
            )
        }
        var detail = ["app": name, "matches": String(matches.count)]
        detail["role"] = best.node.role
        detail["label"] = [best.node.title, best.node.label, best.node.value]
            .compactMap { $0 }.first { (text: String) in !text.isEmpty }
        let others: [CGRect] = matches.dropFirst().prefix(reportedAlternatives).compactMap { $0.node.frame }
        if !others.isEmpty {
            detail["alternatives"] = others.map(rectText).joined(separator: " ")
        }
        return ResolvedTarget(shape: .rect(frame), source: "element", detail: detail)
    }

    public static func rectText(_ rect: CGRect) -> String {
        "\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))"
    }

    public static func application(named name: String?) throws -> NSRunningApplication {
        guard let name else {
            guard let front = NSWorkspace.shared.frontmostApplication else {
                throw BigArrowError.unresolvable("no frontmost app, pass --app")
            }
            return front
        }
        let apps = WindowTarget.runningApps()
        guard let match = WindowMatcher.apps(matching: name, in: apps).first,
              let running = NSRunningApplication(processIdentifier: match.pid) else {
            let names = WindowMatcher.appsWithWindows(apps, WindowTarget.onScreenWindows()).joined(separator: ", ")
            throw BigArrowError.unresolvable("no running app matches '\(name)'; apps with windows: \(names)")
        }
        return running
    }
}
