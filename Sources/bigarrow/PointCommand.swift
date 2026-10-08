import ArgumentParser
import BigArrowCore
import BigArrowOverlay

/// How `point` and `start` differ: `start` runs in the background and stays until `stop`.
enum PointMode {
    case foreground
    case background
}

struct PointCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "point",
        abstract: "Draw a big arrow with a sign that points at a target, for a time limit (default 8 s).",
        discussion: """
        Pick exactly one target: --at, --rect, --mouse, --window, --element, --peekaboo or --peekaboo-window.

        Three ways an arrow ends:
          time limit   bigarrow point --at 760,500 --text "Franz, click HERE" --duration 10
          start, stop  bigarrow start --at 760,500 --text "Sign here"   then   bigarrow stop
          click X      bigarrow point --at 760,500 --text "Check this" --close-button

        More examples:
          bigarrow point --window "Google Chrome" --anchor title --text "This window" --raise
          bigarrow point --element "Reload" --app "Google Chrome" --text "Click reload" --raise --say
          bigarrow point --mouse --text "You are here" --duration 3
          bigarrow point --rect 400,300,200,80 --text "Type your name" --style box --color blue
          peekaboo see --app Safari --json > snap.json && bigarrow point --peekaboo elem_12 --snapshot snap.json --text "This one"
        """
    )

    @OptionGroup var target: TargetOptions
    @OptionGroup var look: LookOptions
    @OptionGroup var behaviour: BehaviourOptions

    func run() throws {
        try MainActor.assumeIsolated {
            let config = try PointConfig(target: target, look: look, behaviour: behaviour, mode: .foreground)
            try PointRunner(config: config).run()
        }
    }
}

struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Put an arrow up in the background until 'bigarrow stop' (same options as point).",
        discussion: "Returns at once and prints the pid. Same as 'point --detach --duration 0'; --duration still sets a limit."
    )

    @OptionGroup var target: TargetOptions
    @OptionGroup var look: LookOptions
    @OptionGroup var behaviour: BehaviourOptions

    func run() throws {
        try MainActor.assumeIsolated {
            let config = try PointConfig(target: target, look: look, behaviour: behaviour, mode: .background)
            try PointRunner(config: config).run()
        }
    }
}
