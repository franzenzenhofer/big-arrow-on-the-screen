import ArgumentParser
import BigArrowCore
import BigArrowOverlay

/// How `point` and `start` differ: `start` runs in the background and stays until `stop` (at most 300 s by default).
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

        --app App[:window or tab title] (or --window) brings the target's app to the
        front; the arrow hides while another app covers the target.
        Every arrow ends by itself: time limit (point 8 s, start 300 s), 'stop',
        or when the agent that drew it exits (CLAUDE_PID, BIGARROW_OWNER_PID).

          bigarrow point --at 760,500 --text "Franz, click HERE" --duration 10
          bigarrow start --rect 400,300,200,40 --app "Google Chrome:Sign in" \\
            --text "Franz, sign in"      then      bigarrow stop

        More examples:
          bigarrow point --window "Google Chrome" --anchor title --text "This window"
          bigarrow point --element "Reload" --app "Google Chrome" --text "Click reload" --say
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
        discussion: "Returns at once and prints the pid. Same as 'point --detach --duration 300'; --duration 0 = no limit."
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
