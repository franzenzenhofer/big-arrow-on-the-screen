import BigArrowCore
import CoreGraphics
import Testing

/// Recorded on 2026-10-08 from the live window server and from Calculator's Accessibility tree.
@Suite("Matchers")
struct MatcherTests {
    struct WindowFixture: Decodable {
        let apps: [RunningAppInfo]
        let windows: [WindowInfo]
    }

    let recorded: WindowFixture
    let calculator: [AXNodeInfo]
    let displays = TestDisplays.singleDisplay.displays

    init() throws {
        recorded = try Fixture.decode(WindowFixture.self, "windows-recorded.json")
        calculator = try Fixture.decode([AXNodeInfo].self, "ax-calculator.json")
    }

    @Test("Apps match by exact name, then bundle id, case-insensitively")
    func appMatching() {
        #expect(WindowMatcher.apps(matching: "google chrome", in: recorded.apps).map(\.name) == ["Google Chrome"])
        #expect(WindowMatcher.apps(matching: "com.apple.calculator", in: recorded.apps).map(\.name) == ["Calculator"])
        #expect(WindowMatcher.apps(matching: "Calc", in: recorded.apps).map(\.name) == ["Calculator"])
        #expect(WindowMatcher.apps(matching: "No Such App", in: recorded.apps).isEmpty)
    }

    @Test("Exact names beat substrings: 'Terminal' is not 'Ghostty Terminal'")
    func exactBeatsSubstring() {
        let apps = recorded.apps + [RunningAppInfo(pid: 1, name: "Terminal Helper", bundleID: nil)]
        #expect(WindowMatcher.apps(matching: "terminal", in: apps).map(\.name) == ["Terminal"])
    }

    @Test("Windows are the app's visible layer-0 windows, front to back, menu bar items excluded")
    func windowsOfApp() throws {
        let chrome = WindowMatcher.apps(matching: "Google Chrome", in: recorded.apps).map(\.pid)
        let windows = WindowMatcher.windows(of: chrome, in: recorded.windows, title: nil, displays: displays)
        #expect(windows.count == 3)
        #expect(windows.allSatisfy { $0.layer == 0 })
        #expect(windows.first?.bounds == CGRect(x: 968, y: 144, width: 320, height: 448))
    }

    @Test("Two apps with the same name: the active one wins, else the one with the frontmost window")
    func sameNamedApps() {
        let first = RunningAppInfo(pid: 10, name: "Google Chrome", bundleID: "com.google.Chrome")
        let second = RunningAppInfo(pid: 20, name: "Google Chrome", bundleID: "com.google.Chrome")
        let windows = [
            WindowInfo(ownerPID: 20, layer: 0, bounds: CGRect(x: 40, y: 60, width: 900, height: 700), alpha: 1, title: nil),
            WindowInfo(ownerPID: 10, layer: 0, bounds: CGRect(x: 0, y: 40, width: 900, height: 700), alpha: 1, title: nil)
        ]
        let matches = [first, second]
        #expect(WindowMatcher.preferred(matches, activePID: 10, windows: windows, displays: displays)?.pid == 10)
        #expect(WindowMatcher.preferred(matches, activePID: 99, windows: windows, displays: displays)?.pid == 20)
        #expect(WindowMatcher.preferred(matches, activePID: nil, windows: [], displays: displays)?.pid == 10)
    }

    @Test("Title filtering is a case-insensitive substring match")
    func titleFilter() {
        let calculator = WindowMatcher.apps(matching: "Calculator", in: recorded.apps).map(\.pid)
        #expect(WindowMatcher.windows(of: calculator, in: recorded.windows, title: "calc", displays: displays).count == 1)
        #expect(WindowMatcher.windows(of: calculator, in: recorded.windows, title: "inbox", displays: displays).isEmpty)
    }

    @Test("A window parked off-screen is skipped, the visible one is taken (seen on a CI runner)")
    func offScreenWindowsAreSkipped() {
        let parked = WindowInfo(ownerPID: 7, layer: 0, bounds: CGRect(x: 312, y: -252, width: 400, height: 28), alpha: 1, title: nil)
        let visible = WindowInfo(ownerPID: 7, layer: 0, bounds: CGRect(x: 252, y: 124, width: 520, height: 288), alpha: 1, title: nil)
        #expect(WindowMatcher.windows(of: [7], in: [parked, visible], title: nil, displays: displays) == [visible])
    }

    @Test("The unknown-app message lists only apps with visible windows")
    func appsWithWindows() {
        let names = WindowMatcher.appsWithWindows(recorded.apps, recorded.windows)
        #expect(names.contains("Calculator"))
        #expect(names.contains("Google Chrome"))
        #expect(names == names.sorted())
    }

    @Test("An exact label beats a substring, and the frame is the button's")
    func exactElement() throws {
        let query = try ElementQuery(text: "equals", role: nil)
        let best = try #require(ElementMatcher.rank(calculator, query: query, displays: displays).first)
        #expect(best.score == 3)
        #expect(best.node.frame == CGRect(x: 478, y: 841, width: 48, height: 48))
    }

    @Test("A role filter narrows matches: 'Show Sidebar' as a button")
    func roleFilter() throws {
        let any = ElementMatcher.rank(calculator, query: try ElementQuery(text: "Mode", role: nil), displays: displays)
        let buttons = ElementMatcher.rank(calculator, query: try ElementQuery(text: "Mode", role: "AXMenuButton"), displays: displays)
        #expect(any.count > buttons.count)
        #expect(buttons.isEmpty)
        let sidebar = ElementMatcher.rank(calculator, query: try ElementQuery(text: "show sidebar", role: "button"), displays: displays)
        #expect(sidebar.count == 2)
        #expect(sidebar.allSatisfy { $0.node.role == "AXButton" })
    }

    @Test("Visible elements rank before invisible ones")
    func visibleFirst() throws {
        let hidden = AXNodeInfo(role: "AXButton", title: "Equals", label: nil, value: nil, identifier: nil,
                                frame: CGRect(x: -5000, y: -5000, width: 10, height: 10), enabled: true)
        let ranked = ElementMatcher.rank([hidden] + calculator, query: try ElementQuery(text: "Equals", role: nil), displays: displays)
        #expect(ranked.first?.visible == true)
        #expect(ranked.last?.visible == false)
    }

    @Test("An empty element label is bad input")
    func emptyLabel() {
        #expect(throws: BigArrowError.self) { try ElementQuery(text: "  ", role: nil) }
    }
}
