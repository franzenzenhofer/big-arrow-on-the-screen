import ArgumentParser

/// Shorthand for an option's help text with a value name.
func help(_ text: String, _ value: String) -> ArgumentHelp {
    ArgumentHelp(text, valueName: value)
}

struct TargetOptions: ParsableArguments {
    @Option(help: help("Point at X,Y in global top-left points (e.g. 760,500).", "x,y"))
    var at: String?

    @Option(help: help("Highlight the rect x,y,w,h with a box and point at it.", "x,y,w,h"))
    var rect: String?

    @Flag(help: "Point at the mouse cursor.")
    var mouse = false

    @Option(help: help("Point at an app's front window, optionally by title: 'Safari' or 'Safari:Inbox'.", "app[:title]"))
    var window: String?

    @Option(help: help("Point inside the window at: center, title, top-left, top-right, bottom-left, bottom-right.", "anchor"))
    var anchor = "center"

    @Option(help: help("Point at the UI element with this label (needs Accessibility for your terminal).", "label"))
    var element: String?

    @Option(help: help(
        "The app the target is in, 'App' or 'App:window or tab title'. It comes to the front first, and the arrow "
            + "hides while another app covers the target. With --element: the app to search (default: the frontmost app).",
        "app[:title]"
    ))
    var app: String?

    @Option(help: help("Only match --element elements with this role, e.g. button.", "role"))
    var role: String?

    @Option(help: help("Point at a Peekaboo element id from 'peekaboo see --json'.", "id"))
    var peekaboo: String?

    @Option(name: .customLong("peekaboo-window"), help: help("Point at window_index N from 'peekaboo window list --json'.", "index"))
    var peekabooWindow: Int?

    @Option(help: help("Peekaboo JSON file for --peekaboo / --peekaboo-window (default: stdin).", "path"))
    var snapshot: String?

    @Option(help: help("With --at or --rect: coordinates are relative to display N (1-based, see 'bigarrow doctor').", "n"))
    var display: Int?

    @Flag(name: .customLong("no-raise"), help: "Leave the windows as they are; by default the target's app and window come to the front.")
    var noRaise = false
}

struct LookOptions: ParsableArguments {
    @Option(help: help("The sign. Write a full sentence: 'Franz, click Allow'.", "text"))
    var text: String

    @Option(help: help(
        "Preferred side for the sign (another side if it does not fit there): auto, top-left, top, top-right, "
            + "right, bottom-right, bottom, bottom-left, left.", "side"
    ))
    var from = "auto"

    @Option(help: help("S, M or L.", "size"))
    var size = "M"

    @Option(help: help("arrow, ring or box.", "style"))
    var style = "arrow"

    @Option(help: help("red, orange, yellow, green, teal, blue, purple, pink, black, white, or hex like #FF3B1F / #F31.", "colour"))
    var color = "red"

    @Option(help: help("Shaft shape: bend, straight or zigzag.", "shape"))
    var shape = "bend"

    @Option(help: help("Sign corners: round or sharp.", "corners"))
    var corners = "round"

    @Flag(help: "Add a soft drop shadow instead of the thin black edge (default: no shadow).")
    var shadow = false

    @Flag(name: .customLong("no-animation"), help: "Show the final frame at once, no draw-on, pulse or fade.")
    var noAnimation = false
}

struct BehaviourOptions: ParsableArguments {
    @Option(help: help("Seconds to show the arrow (point: 8, start/--close-button/--until-click: 300). 0 = until stopped.", "seconds"))
    var duration: Double?

    @Flag(help: "Return at once and leave the arrow up in the background; prints the pid.")
    var detach = false

    @Flag(name: .customLong("close-button"), help: "Show an X in the sign. A click on the sign or the shaft always removes the arrow.")
    var closeButton = false

    @Flag(name: .customLong("until-click"), help: "Dismiss when the human clicks the target (needs Accessibility).")
    var untilClick = false

    @Flag(name: .customLong("until-any-click"), help: "Dismiss on the next click anywhere (needs Accessibility).")
    var untilAnyClick = false

    @Flag(help: "Speak the sign with macOS 'say', for when the human is not looking.")
    var say = false

    @Option(help: help("Voice for --say (see 'say -v ?').", "voice"))
    var voice: String?

    @Flag(help: "Re-resolve --window or --element every 250 ms and move the arrow with it.")
    var follow = false

    @Flag(help: "Print a JSON result to stdout (errors as JSON on stderr).")
    var json = false

    @Flag(name: .customLong("dry-run"), help: "Resolve the target and plan the layout, draw nothing.")
    var dryRun = false

    @Option(help: help("Render the arrow into this PNG (transparent background) instead of showing it.", "file"))
    var png: String?
}
