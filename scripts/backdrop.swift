// A neutral demo window for screenshots and tests: a small "permission" dialog with Cancel and
// Allow buttons, nothing personal. Exits after 5 minutes or on SIGTERM.
// `backdrop --fullscreen` puts the window into its own full-screen Space.
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
    styleMask: [.titled], backing: .buffered, defer: false
)
window.title = "Demo App"
let content = NSView(frame: window.contentRect(forFrameRect: window.frame))
let label = NSTextField(labelWithString: "\"Demo App\" would like to access your Downloads folder.")
label.font = .systemFont(ofSize: 16, weight: .semibold)
label.frame = NSRect(x: 30, y: 150, width: 460, height: 40)
let cancel = NSButton(title: "Cancel", target: nil, action: nil)
cancel.frame = NSRect(x: 250, y: 40, width: 110, height: 32)
let allow = NSButton(title: "Allow", target: nil, action: nil)
allow.frame = NSRect(x: 380, y: 40, width: 110, height: 32)
allow.keyEquivalent = "\r"
content.addSubview(label)
content.addSubview(cancel)
content.addSubview(allow)
window.contentView = content
window.center()
window.collectionBehavior = [.fullScreenPrimary]
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
if CommandLine.arguments.contains("--fullscreen") {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { window.toggleFullScreen(nil) }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 300) { exit(0) }
app.run()
