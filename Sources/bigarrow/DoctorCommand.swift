import AppKit
import ArgumentParser
import BigArrowCore
import BigArrowOverlay
import BigArrowTargeting

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Show permissions, the app that owns them, displays and Peekaboo.",
        discussion: """
        Drawing needs no permission. --element and --until-click need Accessibility, a window \
        title match needs Screen Recording; both are granted to the app that runs your shell \
        (Terminal, iTerm2, VS Code, ...), never to bigarrow. Exit 4 when a --require is missing.
        """
    )

    @Flag(help: "Print JSON.")
    var json = false

    @Option(help: ArgumentHelp("Exit 4 unless this permission is granted: accessibility, screen-recording.", valueName: "permission"))
    var require: [String] = []

    @Flag(name: .customLong("open-settings"), help: "Open System Settings at Privacy & Security > Accessibility.")
    var openSettings = false

    @Flag(name: .customLong("request-accessibility"), help: "Ask macOS to show its Accessibility prompt for the responsible app.")
    var requestAccessibility = false

    func run() throws {
        let required = try require.map { raw in
            guard let permission = Permission(rawValue: raw.lowercased()) else {
                throw BigArrowError.badInput("--require '\(raw)' is not one of accessibility, screen-recording")
            }
            return permission
        }
        try MainActor.assumeIsolated {
            if requestAccessibility { _ = Permission.requestAccessibility() }
            if openSettings, let url = URL(string: Permission.accessibility.settingsURL) { NSWorkspace.shared.open(url) }
            let report = Doctor.report(screens: ScreenReader.current(), required: required)
            if json { Output.json(report) } else { DoctorText.print(report) }
            if let first = required.first(where: { !$0.isGranted }) {
                throw first.missing(for: "This check")
            }
        }
    }
}

enum DoctorText {
    static func print(_ report: DoctorReport) {
        let owner = report.responsibleApp.map { "\($0.name) (\($0.bundleID ?? $0.path))" }
            ?? "none found in the parent chain (tmux, SSH or launchd); grant the app that started the shell"
        let lines = [
            "bigarrow \(report.version) on macOS \(report.macOS)",
            "drawing:          no permission needed",
            "accessibility:    \(mark(report.accessibility)) (for --element, --until-click)",
            "screen recording: \(mark(report.screenRecording)) (for --window App:title)",
            "permissions belong to: \(owner)",
            "peekaboo:         \(report.peekaboo ?? "not on PATH (optional)")",
            "displays (global top-left points, separate Spaces: \(report.screensHaveSeparateSpaces ? "yes" : "no")):"
        ] + report.displays.map { display in
            "  \(display.number): origin \(Output.number(display.x)),\(Output.number(display.y))  "
                + "\(Output.number(display.width))x\(Output.number(display.height)) @\(Output.number(display.scale))x  id \(display.id)"
        }
        lines.forEach(Output.print)
    }

    static func mark(_ granted: Bool) -> String { granted ? "granted" : "missing" }
}
