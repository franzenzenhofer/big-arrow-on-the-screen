import AppKit
import CoreGraphics
import Foundation
import BigArrowCore
import BigArrowOverlay
import ImageIO

/// Reads the live window server and screen, the way a human would see the arrow.
enum WindowServer {
    struct Window {
        let number: Int
        let layer: Int
        let bounds: CGRect
    }

    /// Polls briefly, the window server lists a new window a moment after it is ordered front.
    static func waitForWindows(of pid: Int32, timeout: TimeInterval = 1) -> [Window] {
        let deadline = Date().addingTimeInterval(timeout)
        var found = windows(of: pid)
        while found.isEmpty, Date() < deadline {
            usleep(20_000)
            found = windows(of: pid)
        }
        return found
    }

    static func windows(of pid: Int32) -> [Window] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { entry in
            guard entry[kCGWindowOwnerPID as String] as? Int32 == pid,
                  let dict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary) else { return nil }
            return Window(
                number: entry[kCGWindowNumber as String] as? Int ?? 0,
                layer: entry[kCGWindowLayer as String] as? Int ?? 0, bounds: bounds
            )
        }
    }

    /// Pids that own at least one window `--window` would accept: the CLI's own rule, so the
    /// test never picks an app whose only windows are transparent or parked off every display.
    @MainActor
    static func visibleAppWindowOwners() -> [Int32] {
        let all = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
            .compactMap(windowInfo)
        let displays = ScreenReader.current().displays
        return WindowMatcher.windows(of: all.map(\.ownerPID), in: all, title: nil, displays: displays).map(\.ownerPID)
    }

    static func windowInfo(_ entry: [String: Any]) -> WindowInfo? {
        guard let pid = entry[kCGWindowOwnerPID as String] as? Int32,
              let dict = entry[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary) else { return nil }
        return WindowInfo(
            ownerPID: pid, layer: entry[kCGWindowLayer as String] as? Int ?? 0, bounds: bounds,
            alpha: entry[kCGWindowAlpha as String] as? Double ?? 1, title: nil
        )
    }

    /// Which window a click at this global top-left point would hit.
    @MainActor
    static func windowNumberHit(at point: CGPoint) -> Int {
        let height = NSScreen.screens[0].frame.height
        return NSWindow.windowNumber(at: NSPoint(x: point.x, y: height - point.y), belowWindowWithWindowNumber: 0)
    }

    /// RGB of one screen point via `screencapture`; needs Screen Recording for the test runner.
    struct RGB {
        let red: Int
        let green: Int
        let blue: Int
    }

    static func color(at point: CGPoint) throws -> RGB {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("bigarrow-pixel-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: file) }
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-R", "\(Int(point.x)),\(Int(point.y)),1,1", file.path]
        try capture.run()
        capture.waitUntilExit()
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return RGB(red: Int(pixel[0]), green: Int(pixel[1]), blue: Int(pixel[2]))
    }
}
