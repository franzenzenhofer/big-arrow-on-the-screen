// Test helper for scripts/behaviour-check.sh, run only on a disposable machine (CI runner):
//   testkit click X Y                posts a left click at global top-left point X,Y
//   testkit move-window APP X Y      moves APP's first window to X,Y via Accessibility
//   testkit resize-window APP W H    resizes APP's first window via Accessibility
//   testkit frontmost                prints the frontmost app's name
//   testkit activate APP             brings APP to the front
//   testkit windows APP              prints APP's windows as the window server lists them
//   testkit pixel X Y                prints the screen colour at X,Y as "r g b" (0-255)
//   testkit cpu PID SECONDS          prints the CPU share PID used over SECONDS, in percent
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

func firstWindow(of name: String) -> AXUIElement {
    let element = AXUIElementCreateApplication(app(named: name).processIdentifier)
    var windows: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
    guard let window = (windows as? [AXUIElement])?.first else { exit(1) }
    return window
}

func moveWindow(of name: String, to point: CGPoint) {
    var position = point
    guard let value = AXValueCreate(.cgPoint, &position) else { exit(1) }
    exit(AXUIElementSetAttributeValue(firstWindow(of: name), kAXPositionAttribute as CFString, value) == .success ? 0 : 1)
}

func resizeWindow(of name: String, to size: CGSize) {
    var extent = size
    guard let value = AXValueCreate(.cgSize, &extent) else { exit(1) }
    exit(AXUIElementSetAttributeValue(firstWindow(of: name), kAXSizeAttribute as CFString, value) == .success ? 0 : 1)
}

let args = CommandLine.arguments
switch args.dropFirst().first {
case "click": click(CGPoint(x: Double(args[2]) ?? 0, y: Double(args[3]) ?? 0))
case "move-window": moveWindow(of: args[2], to: CGPoint(x: Double(args[3]) ?? 0, y: Double(args[4]) ?? 0))
case "windows":
    let pid = app(named: args[2]).processIdentifier
    let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    for entry in list where entry[kCGWindowOwnerPID as String] as? Int32 == pid {
        let keys = [kCGWindowNumber, kCGWindowLayer, kCGWindowBounds, kCGWindowIsOnscreen, kCGWindowAlpha, kCGWindowName]
        print(keys.map { "\($0 as String)=\(entry[$0 as String] ?? "-")" }.joined(separator: " ").replacingOccurrences(of: "\n", with: ""))
    }
case "pixel":
    let file = "/tmp/testkit-pixel.png"
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-R", "\(args[2]),\(args[3]),1,1", file]
    try? capture.run()
    capture.waitUntilExit()
    guard let image = NSImage(contentsOfFile: file), let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff), let color = bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB) else { exit(1) }
    print(Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
case "cpu":
    let pid = args[2]
    let seconds = Double(args[3]) ?? 5
    func cpuTime() -> Double {
        let ps = Process()
        let pipe = Pipe()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-o", "cputime=", "-p", pid]
        ps.standardOutput = pipe
        try? ps.run()
        ps.waitUntilExit()
        let text = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":").compactMap { Double($0) }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
    let start = cpuTime()
    Thread.sleep(forTimeInterval: seconds)
    print(String(format: "%.2f", (cpuTime() - start) / seconds * 100))
case "resize-window": resizeWindow(of: args[2], to: CGSize(width: Double(args[3]) ?? 800, height: Double(args[4]) ?? 600))
case "frontmost": print(NSWorkspace.shared.frontmostApplication?.localizedName ?? "")
case "activate":
    app(named: args[2]).activate()
    RunLoop.main.run(until: Date().addingTimeInterval(1))
default:
    FileHandle.standardError.write(Data("usage: testkit click|move-window|frontmost|activate ...\n".utf8))
    exit(2)
}
