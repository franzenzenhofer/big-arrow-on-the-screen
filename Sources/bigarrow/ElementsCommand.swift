import ArgumentParser
import BigArrowCore
import BigArrowOverlay
import BigArrowTargeting

struct ElementsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "elements",
        abstract: "List the visible, labelled UI elements of an app that --element can point at.",
        discussion: "Needs Accessibility for the app that runs your shell. Coordinates are global top-left points."
    )

    @Option(help: ArgumentHelp("App name or bundle id (default: the frontmost app).", valueName: "name"))
    var app: String?

    @Option(help: ArgumentHelp("Only elements whose label contains this text.", valueName: "text"))
    var match: String?

    @Option(help: ArgumentHelp("Only elements with this role, e.g. button.", valueName: "role"))
    var role: String?

    @Flag(help: "Print JSON (the same shape the element matcher reads).")
    var json = false

    func run() throws {
        try MainActor.assumeIsolated {
            try Permission.accessibility.require(for: "Listing UI elements")
            let screens = ScreenReader.current()
            let running = try ElementTarget.application(named: app, screens: screens)
            let displays = screens.displays
            let nodes = AXWalker(pid: running.processIdentifier).walk().filter { node in
                ElementMatcher.isVisible(node, displays) && !node.texts.isEmpty && matches(node)
            }
            if json {
                Output.json(nodes)
                return
            }
            for node in nodes {
                let frame = node.frame.map(ElementTarget.rectText) ?? "-"
                let label = [node.title, node.label, node.value].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
                Output.print("\(frame)  \(node.role ?? "?")  \(label)")
            }
        }
    }

    func matches(_ node: AXNodeInfo) -> Bool {
        if let role, ElementQuery.normalizedRole(node.role ?? "") != ElementQuery.normalizedRole(role) { return false }
        guard let match else { return true }
        return node.texts.contains { $0.contains(match.lowercased()) }
    }
}
