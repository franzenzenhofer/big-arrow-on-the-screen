import ArgumentParser
import BigArrowCore
import BigArrowOverlay
import BigArrowTargeting

struct FrontCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "front",
        abstract: "Bring an app (and optionally one of its windows) to the front before pointing.",
        discussion: """
        Examples:
          bigarrow front --app "Google Chrome"
          bigarrow front --app Safari --window Inbox     (raising a window by title needs Accessibility)
        'point --raise' does the same as part of pointing.
        """
    )

    @Option(help: help("App name or bundle id.", "name"))
    var app: String

    @Option(help: help("Also raise the app's window whose title contains this text.", "title"))
    var window: String?

    @Flag(help: "Print JSON.")
    var json = false

    func run() throws {
        try MainActor.assumeIsolated {
            let raised = try AppRaiser.raise(app: app, windowTitle: window, screens: ScreenReader.current())
            if json {
                Output.json(raised)
            } else {
                Output.print("bigarrow: \(raised.app) is in front" + (raised.window.map { ", window '\($0)' raised" } ?? ""))
            }
        }
    }
}
