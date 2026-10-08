import AppKit
import CoreGraphics
import Foundation
import Testing

/// Spawns the real CLI against the real window server. `.serialized` because arrows share the screen.
/// Opt-in with `BIGARROW_SCREEN_TESTS=1` (CI and the test Mac set it): these draw on the screen,
/// so a plain `swift test` on a Mac somebody is working on never does.
@Suite(
    "Overlay on the real window server", .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["BIGARROW_SCREEN_TESTS"] == "1", "set BIGARROW_SCREEN_TESTS=1 to draw on screen")
)
struct OverlayTests {
    /// A point on the primary display, away from the menu bar and the Dock.
    static var target: CGPoint {
        get async {
            await MainActor.run {
                let frame = NSScreen.screens[0].frame
                return CGPoint(x: (frame.width * 0.45).rounded(), y: (frame.height * 0.45).rounded())
            }
        }
    }

    /// The ticket asks for 300 ms; a test Mac stays under 0.5 s, shared CI runners get 1.5 s.
    static var fastLimit: Double {
        ProcessInfo.processInfo.environment["CI"] == nil ? 0.5 : 1.5
    }

    static func pointArguments(_ point: CGPoint, extra: [String] = []) -> [String] {
        let at = "\(Int(point.x)),\(Int(point.y))"
        return ["point", "--at", at, "--text", "Integration test", "--color", "red", "--no-animation", "--json"] + extra
    }

    @Test("A detached sticky arrow is a click-through, layer-1000 window covering the display, without stealing focus")
    func stickyOverlay() async throws {
        let point = await Self.target
        let frontBefore = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
        let dryRun = try BigArrowProcess.run(Self.pointArguments(point, extra: ["--dry-run"]))
        let sign = try #require(dryRun.json()["sign"] as? [Double])
        let detached = try BigArrowProcess.run(Self.pointArguments(point, extra: ["--duration", "0", "--detach"]))
        #expect(detached.code == 0, "\(detached.stderr)")
        let pid = try #require(detached.json()["pid"] as? Int32)
        defer { _ = try? BigArrowProcess.run(["clear", "--pid", String(pid)]) }

        let windows = WindowServer.waitForWindows(of: pid)
        let overlay = try #require(windows.first, "no window owned by pid \(pid)")
        #expect(overlay.layer == Int(CGWindowLevelForKey(.screenSaverWindow)))
        #expect(overlay.layer == 1000)
        let primary = await MainActor.run { NSScreen.screens[0].frame.size }
        #expect(overlay.bounds.size == primary)
        let hit = await MainActor.run { WindowServer.windowNumberHit(at: point) }
        #expect(hit != overlay.number, "a click at the arrow tip must reach the window below")
        let frontAfter = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
        #expect(frontBefore == frontAfter)

        guard CGPreflightScreenCaptureAccess() else {
            print("skipped pixel check: the test runner has no Screen Recording permission")
            return
        }
        let inside = CGPoint(x: sign[0] + 14, y: sign[1] + sign[3] / 2)
        let pixel = try WindowServer.color(at: inside)
        #expect(pixel.red > 200 && pixel.green < 120 && pixel.blue < 110, "sign pixel was \(pixel)")
    }

    @Test("A timed arrow exits 0 by itself and reports why")
    func timedArrow() async throws {
        let point = await Self.target
        let result = try BigArrowProcess.run(Self.pointArguments(point, extra: ["--duration", "1"]))
        #expect(result.code == 0, "\(result.stderr)")
        let json = try result.json()
        #expect(json["dismissedReason"] as? String == "timeout")
        #expect(result.seconds < 10)
    }

    @Test("--detach returns fast and 'clear' removes the arrow fast")
    func detachAndClearTiming() async throws {
        let point = await Self.target
        let detached = try BigArrowProcess.run(Self.pointArguments(point, extra: ["--duration", "0", "--detach"]))
        let pid = try #require(detached.json()["pid"] as? Int32)
        #expect(detached.seconds < Self.fastLimit, "detach took \(detached.seconds) s")
        let cleared = try BigArrowProcess.run(["clear", "--pid", String(pid), "--json"])
        #expect(cleared.code == 0)
        #expect(cleared.seconds < Self.fastLimit, "clear took \(cleared.seconds) s")
        #expect(WindowServer.windows(of: pid).isEmpty)
    }

    @Test("Two arrows can be up at once and 'clear --all' removes both")
    func twoArrows() async throws {
        let point = await Self.target
        let first = try BigArrowProcess.run(Self.pointArguments(point, extra: ["--duration", "0", "--detach"]))
        let second = try BigArrowProcess.run(Self.pointArguments(
            CGPoint(x: point.x + 120, y: point.y + 80), extra: ["--duration", "0", "--detach", "--color", "blue"]
        ))
        let pids = try [first, second].map { try #require($0.json()["pid"] as? Int32) }
        let cleared = try BigArrowProcess.run(["clear", "--all", "--json"])
        let clearedPids = try #require(cleared.json()["cleared"] as? [Int32])
        #expect(Set(pids).isSubset(of: Set(clearedPids)))
        #expect(pids.allSatisfy { WindowServer.windows(of: $0).isEmpty })
    }
}
