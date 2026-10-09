import AppKit
import CoreGraphics
import Foundation
import Testing

/// Exit codes, errors and target resolution through the real binary, drawing nothing (--dry-run).
@Suite("CLI contract")
struct CLITests {
    @Test("--version prints the version")
    func version() throws {
        let result = try BigArrowProcess.run(["--version"])
        #expect(result.code == 0)
        #expect(result.stdout.hasPrefix("bigarrow "))
    }

    @Test("A point outside every display exits 2 with a one-line message")
    func outside() throws {
        let result = try BigArrowProcess.run(["point", "--at", "99999,0", "--text", "x"])
        #expect(result.code == 2)
        #expect(result.stderr.contains("point is outside every display"))
        #expect(!result.stderr.contains("\n"))
    }

    @Test("Errors are JSON on stderr with --json")
    func jsonError() throws {
        let result = try BigArrowProcess.run(["point", "--at", "1,2", "--text", "x", "--color", "rainbow", "--json"])
        #expect(result.code == 2)
        let json = try result.json()
        #expect(json["ok"] as? Bool == false)
        #expect(json["code"] as? Int == 2)
    }

    @Test("Argument parser errors are bad input too (exit 2)")
    func parserErrors() throws {
        #expect(try BigArrowProcess.run(["point", "--text", "x", "--bogus"]).code == 2)
        #expect(try BigArrowProcess.run(["point", "--at", "1,2"]).code == 2)
        #expect(try BigArrowProcess.run(["point", "--at", "1,2", "--mouse", "--text", "x"]).code == 2)
    }

    @Test("--mouse points within 2 pt of the cursor")
    func mouse() throws {
        let before = try #require(CGEvent(source: nil)?.location)
        let json = try BigArrowProcess.run(["point", "--mouse", "--text", "x", "--dry-run", "--json"]).json()
        let after = try #require(CGEvent(source: nil)?.location)
        guard hypot(after.x - before.x, after.y - before.y) <= 2 else {
            print("skipped: the mouse moved while the test ran")
            return
        }
        let target = try #require(json["target"] as? [String: Any])
        let x = try #require(target["x"] as? Double)
        let y = try #require(target["y"] as? Double)
        #expect(hypot(x - before.x, y - before.y) <= 2)
    }

    @Test("--display makes coordinates relative to that display")
    func displayRelative() throws {
        let json = try BigArrowProcess.run(["point", "--at", "100,100", "--display", "1", "--text", "x", "--dry-run", "--json"]).json()
        let target = try #require(json["target"] as? [String: Any])
        #expect(target["display"] as? Int == 1)
        #expect(try BigArrowProcess.run(["point", "--at", "1,1", "--display", "99", "--text", "x"]).code == 2)
    }

    @Test("--rect targets report the rect and get a box")
    func rect() throws {
        let json = try BigArrowProcess.run(["point", "--rect", "300,300,200,80", "--text", "x", "--dry-run", "--json"]).json()
        let target = try #require(json["target"] as? [String: Any])
        #expect(target["rect"] as? [Double] == [300, 300, 200, 80])
    }

    @Test("A recorded Peekaboo 4.9.0 snapshot resolves from a file and from stdin")
    func peekaboo() async throws {
        let path = BigArrowProcess.fixture("peekaboo-see-4.9.0.json")
        let fromFile = try BigArrowProcess.run(["point", "--peekaboo", "elem_28", "--snapshot", path, "--text", "x", "--dry-run", "--json"])
        let recordedCenter = CGPoint(x: 502, y: 865)
        let onScreen = await MainActor.run {
            let height = NSScreen.screens[0].frame.height
            return NSScreen.screens.contains { $0.frame.contains(CGPoint(x: recordedCenter.x, y: height - recordedCenter.y)) }
        }
        guard onScreen else {
            #expect(fromFile.code == 2, "the recorded element is off this machine's screens, so it is bad input")
            print("skipped the stdin half: the recorded element lies outside this machine's displays")
            return
        }
        let target = try #require(fromFile.json()["target"] as? [String: Any])
        #expect(target["rect"] as? [Double] == [478, 841, 48, 48])
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let fromStdin = try BigArrowProcess.run(["point", "--peekaboo", "elem_28", "--text", "x", "--dry-run", "--json"], stdin: data)
        #expect(fromStdin.code == 0, "\(fromStdin.stderr)")
        let old = BigArrowProcess.fixture("peekaboo-see-3.0.0-beta3.json")
        #expect(try BigArrowProcess.run(["point", "--peekaboo", "elem_9", "--snapshot", old, "--text", "x"]).code == 2)
    }

    @Test("An unknown app exits 3 and names apps that have windows")
    func unknownApp() throws {
        let result = try BigArrowProcess.run(["point", "--window", "No Such App 4711", "--text", "x"])
        #expect(result.code == 3)
        #expect(result.stderr.contains("apps with windows"))
    }

    @Test("--window resolves an app's front window by pid, without any permission")
    func window() async throws {
        let app = await MainActor.run { () -> String? in
            let pids = Set(WindowServer.visibleAppWindowOwners())
            let apps = NSWorkspace.shared.runningApplications
            return apps.first { pids.contains($0.processIdentifier) && $0.localizedName != nil }?.localizedName
        }
        guard let app else {
            print("skipped: no app with a visible window")
            return
        }
        let result = try BigArrowProcess.run(["point", "--window", app, "--anchor", "title", "--text", "x", "--dry-run", "--json"])
        #expect(result.code == 0, "\(result.stderr)")
        let target = try #require(result.json()["target"] as? [String: Any])
        #expect(target["source"] as? String == "window")
    }

    @Test("--element finds Finder's 'File' menu through Accessibility")
    func element() throws {
        guard AXIsProcessTrusted() else {
            print("skipped: the test runner's responsible app has no Accessibility permission")
            let result = try BigArrowProcess.run(["point", "--element", "File", "--app", "Finder", "--text", "x"])
            #expect(result.code == 4)
            return
        }
        let result = try BigArrowProcess.run([
            "point", "--element", "File", "--app", "Finder", "--role", "menubaritem", "--text", "x", "--dry-run", "--json"
        ])
        #expect(result.code == 0, "\(result.stderr)")
        let target = try #require(result.json()["target"] as? [String: Any])
        #expect((target["detail"] as? [String: String])?["role"] == "AXMenuBarItem")
    }

    @Test(
        "A dry run never raises an app, although --window raises by default",
        .enabled(if: ProcessInfo.processInfo.environment["BIGARROW_SCREEN_TESTS"] == "1", "a regression would steal the focus")
    )
    func dryRunDoesNotRaise() async throws {
        let front = await MainActor.run { NSWorkspace.shared.frontmostApplication }
        let other = await MainActor.run {
            NSWorkspace.shared.runningApplications.first { $0.activationPolicy == .regular && $0 != front && $0.localizedName != nil }
        }
        guard let name = other?.localizedName else {
            print("skipped: no second regular app is running")
            return
        }
        _ = try BigArrowProcess.run(["point", "--window", name, "--text", "x", "--dry-run"])
        let after = await MainActor.run { NSWorkspace.shared.frontmostApplication }
        #expect(after == front)
    }

    @Test("--window names its own app, so --app next to it is bad input")
    func windowWithApp() throws {
        let result = try BigArrowProcess.run(["point", "--window", "Finder", "--app", "Finder", "--text", "x", "--dry-run"])
        #expect(result.code == 2)
        #expect(result.stderr.contains("drop --app"))
    }

    @Test("--app works with coordinate targets and --no-raise is accepted")
    func appWithCoordinates() throws {
        let result = try BigArrowProcess.run(["point", "--at", "10,10", "--app", "Finder", "--no-raise", "--text", "x", "--dry-run"])
        #expect(result.code == 0, "\(result.stderr)")
    }

    @Test("--border and every colour option are accepted; unknown values are bad input")
    func lookOptions() throws {
        let base = ["point", "--at", "10,10", "--text", "x", "--dry-run"]
        let colours = ["--border-color", "red", "--text-color", "#00FF00", "--edge-color", "purple",
                       "--close-color", "black", "--close-x-color", "white", "--close-button"]
        for border in ["shadow", "white-black", "black"] {
            #expect(try BigArrowProcess.run(base + ["--border", border] + colours).code == 0, "--border \(border)")
        }
        #expect(try BigArrowProcess.run(base + ["--border", "glow"]).code == 2)
        #expect(try BigArrowProcess.run(base + ["--text-color", "rainbow"]).code == 2)
    }

    @Test("stop --hook prints nothing and exits 0, also for a session without arrows")
    func stopHook() throws {
        let result = try BigArrowProcess.run(["stop", "--hook"], stdin: Data(#"{"session_id":"no-such-session","prompt":"hi"}"#.utf8))
        #expect(result.code == 0)
        #expect(result.stdout.isEmpty)
        #expect(try BigArrowProcess.run(["stop", "--hook"], stdin: Data("not json".utf8)).code == 0)
    }

    @Test("doctor reports displays and the permission owner as JSON")
    func doctor() throws {
        let result = try BigArrowProcess.run(["doctor", "--json"])
        #expect(result.code == 0)
        let json = try result.json()
        #expect((json["displays"] as? [Any])?.isEmpty == false)
        #expect(json["drawingNeedsPermission"] as? Bool == false)
        #expect(json["accessibility"] as? Bool == AXIsProcessTrusted())
    }
}
