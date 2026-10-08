// Test helper for scripts/behaviour-check.sh, run only on a disposable machine (CI runner):
//   testkit click X Y                posts a left click at global top-left point X,Y
//   testkit move-window APP X Y      moves APP's first window to X,Y via Accessibility
//   testkit frontmost                prints the frontmost app's name
//   testkit activate APP             brings APP to the front
import AppKit
import ApplicationServices

func app(named name: String) -> NSRunningApplication {
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) else {
        FileHandle.standardError.write(Data("testkit: no app named \(name)\n".utf8))
        exit(1)
    }
    return app
}

func click(_ point: CGPoint) {
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(80_000)
    }
}

func moveWindow(of name: String, to point: CGPoint) {
    let element = AXUIElementCreateApplication(app(named: name).processIdentifier)
    var windows: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
    guard let window = (windows as? [AXUIElement])?.first else { exit(1) }
    var position = point
    guard let value = AXValueCreate(.cgPoint, &position) else { exit(1) }
    exit(AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success ? 0 : 1)
}

let args = CommandLine.arguments
switch args.dropFirst().first {
case "click": click(CGPoint(x: Double(args[2]) ?? 0, y: Double(args[3]) ?? 0))
case "move-window": moveWindow(of: args[2], to: CGPoint(x: Double(args[3]) ?? 0, y: Double(args[4]) ?? 0))
case "frontmost": print(NSWorkspace.shared.frontmostApplication?.localizedName ?? "")
case "activate":
    app(named: args[2]).activate()
    RunLoop.main.run(until: Date().addingTimeInterval(1))
default:
    FileHandle.standardError.write(Data("usage: testkit click|move-window|frontmost|activate ...\n".utf8))
    exit(2)
}
