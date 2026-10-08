// A neutral demo window for screenshots and tests, nothing personal and no real brand.
//   backdrop [--fullscreen] [--cover] [--title T] [--message M] [--buttons "Cancel,Allow"] [--x X --y Y]
// --cover paints a neutral background over the main display behind the dialog, so screenshots on
// a Mac in use show nothing but the scene. Defaults: a "Demo App" permission dialog with Cancel and Allow. Exits after 5 minutes or on SIGTERM.
import AppKit

func option(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[index + 1]
}

let title = option("--title") ?? "Demo App"
let message = option("--message") ?? "\"Demo App\" would like to access your Downloads folder."
let buttons = (option("--buttons") ?? "Cancel,Allow").split(separator: ",").map(String.init)

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
    styleMask: [.titled], backing: .buffered, defer: false
)
window.title = title
let content = NSView(frame: window.contentRect(forFrameRect: window.frame))
let label = NSTextField(wrappingLabelWithString: message)
label.font = .systemFont(ofSize: 16, weight: .semibold)
label.frame = NSRect(x: 30, y: 110, width: 460, height: 90)
content.addSubview(label)
var right: CGFloat = 490
for (index, name) in buttons.reversed().enumerated() {
    let button = NSButton(title: name, target: nil, action: nil)
    let width = max(110, CGFloat(name.count) * 9 + 30)
    button.frame = NSRect(x: right - width, y: 40, width: width, height: 32)
    if index == 0 { button.keyEquivalent = "\r" }
    content.addSubview(button)
    right -= width + 20
}
window.contentView = content
window.collectionBehavior = [.fullScreenPrimary]
if let x = option("--x").flatMap(Double.init), let y = option("--y").flatMap(Double.init) {
    window.setFrameTopLeftPoint(NSPoint(x: x, y: (NSScreen.screens.first?.frame.height ?? 0) - y))
} else {
    window.center()
}
var cover: NSWindow?
if CommandLine.arguments.contains("--cover"), let screen = NSScreen.screens.first {
    let background = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    background.backgroundColor = NSColor(calibratedRed: 0.82, green: 0.86, blue: 0.92, alpha: 1)
    background.setFrame(screen.frame, display: true)
    background.orderFront(nil)
    cover = background
}
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
if CommandLine.arguments.contains("--fullscreen") {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { window.toggleFullScreen(nil) }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 300) { exit(0) }
app.run()
