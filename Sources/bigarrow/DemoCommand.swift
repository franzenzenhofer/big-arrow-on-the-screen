import AppKit
import ArgumentParser
import BigArrowCore
import BigArrowOverlay
import Foundation

struct DemoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "demo",
        abstract: "Show what bigarrow can do: an arrow, a ring at the mouse, a box, in sequence."
    )

    @Option(help: ArgumentHelp("Seconds per step.", valueName: "seconds"))
    var step: Double = 3

    func run() throws {
        let steps = MainActor.assumeIsolated { Self.steps(step: step) }
        guard let executable = Bundle.main.executablePath else {
            throw BigArrowError.badInput("cannot find the bigarrow executable")
        }
        for arguments in steps {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw BigArrowError(.targetUnresolvable, "demo step failed: bigarrow \(arguments.joined(separator: " "))")
            }
        }
    }

    /// Steps on the display under the mouse, so the demo shows where the human is looking.
    @MainActor
    static func steps(step: Double) -> [[String]] {
        let screens = ScreenReader.current()
        let mouse = ScreenReader.mouseLocation()
        let display = (try? screens.display(containing: mouse)) ?? screens.displays[0]
        let frame = display.visibleFrame
        let center = "\(Int(frame.midX)),\(Int(frame.midY))"
        let box = "\(Int(frame.minX + frame.width * 0.62)),\(Int(frame.minY + frame.height * 0.62)),220,90"
        let seconds = Output.number(step)
        return [
            ["point", "--at", center, "--text", "bigarrow points at things", "--duration", seconds],
            ["point", "--mouse", "--style", "ring", "--color", "blue", "--text", "You are here", "--duration", seconds],
            ["point", "--rect", box, "--color", "green", "--text", "Type your name here", "--duration", seconds]
        ]
    }
}
