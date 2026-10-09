import BigArrowCore
import CoreGraphics
import Foundation
import Testing

@Suite("Arrow owner and cover")
struct OwnerAndCoverTests {
    @Test("The owner comes from BIGARROW_* first, then Claude Code's variables")
    func ownerFromEnvironment() {
        let claude = ArrowOwner.from(environment: ["CLAUDE_PID": "4711", "CLAUDE_CODE_SESSION_ID": "abc"])
        #expect(claude == ArrowOwner(pid: 4711, session: "abc"))
        let both = ArrowOwner.from(environment: ["CLAUDE_PID": "4711", "BIGARROW_OWNER_PID": "42", "BIGARROW_SESSION": "s"])
        #expect(both == ArrowOwner(pid: 42, session: "s"))
        #expect(ArrowOwner.from(environment: [:]) == ArrowOwner(pid: nil, session: nil))
        #expect(ArrowOwner.from(environment: ["CLAUDE_PID": "-3", "CLAUDE_CODE_SESSION_ID": " "]) == ArrowOwner(pid: nil, session: nil))
    }

    @Test("A pid file written before owners existed still reads")
    func recordWithoutOwner() throws {
        let json = #"{"pid":1,"text":"x","targetX":1,"targetY":2,"display":1,"signFrame":[0,0,1,1],"direction":"top","#
            + #""startedAt":"2026-10-08T10:00:00Z"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(ArrowRecord.self, from: Data(json.utf8))
        #expect(record.owner == nil)
    }

    func window(_ pid: Int32, _ rect: CGRect, layer: Int = 0) -> WindowInfo {
        WindowInfo(ownerPID: pid, layer: layer, bounds: rect, alpha: 1, title: nil)
    }

    @Test("Covered only when another app's normal window is the frontmost one under the point")
    func cover() {
        let chrome: Int32 = 10
        let terminal: Int32 = 20
        let point = CGPoint(x: 100, y: 100)
        let chromeWindow = window(chrome, CGRect(x: 0, y: 0, width: 800, height: 600))
        let terminalWindow = window(terminal, CGRect(x: 50, y: 50, width: 300, height: 300))
        let farTerminal = window(terminal, CGRect(x: 500, y: 0, width: 200, height: 200))
        let menu = window(terminal, CGRect(x: 0, y: 0, width: 400, height: 400), layer: 101)
        #expect(!WindowMatcher.isCovered(point, owners: [chrome], windows: [chromeWindow, terminalWindow]))
        #expect(WindowMatcher.isCovered(point, owners: [chrome], windows: [terminalWindow, chromeWindow]))
        #expect(!WindowMatcher.isCovered(point, owners: [chrome], windows: [farTerminal, menu, chromeWindow]))
        #expect(!WindowMatcher.isCovered(CGPoint(x: 900, y: 900), owners: [chrome], windows: [terminalWindow, chromeWindow]))
    }
}
