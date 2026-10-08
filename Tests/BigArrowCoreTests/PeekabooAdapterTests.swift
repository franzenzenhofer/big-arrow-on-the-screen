import BigArrowCore
import CoreGraphics
import Foundation
import Testing

/// Fixtures recorded on 2026-10-08 against Calculator with the official Peekaboo 4.9.0 release
/// binary and with the Peekaboo 3.0.0-beta3 installed on the planning Mac.
@Suite("Peekaboo adapter")
struct PeekabooAdapterTests {
    @Test("A 4.9.0 'see' element id resolves to its bounds, which are global top-left points")
    func seeElement() throws {
        let target = try PeekabooAdapter.element(id: "elem_28", snapshot: Fixture.data("peekaboo-see-4.9.0.json"))
        #expect(target.shape == .rect(CGRect(x: 478, y: 841, width: 48, height: 48)))
        #expect(target.detail["label"] == "Equals")
        #expect(target.source == "peekaboo")
    }

    @Test("Ids match case-insensitively")
    func caseInsensitive() throws {
        let target = try PeekabooAdapter.element(id: "ELEM_9", snapshot: Fixture.data("peekaboo-see-4.9.0.json"))
        #expect(target.detail["label"] == "Delete")
    }

    @Test("An unknown id is unresolvable (exit 3) and lists the ids that exist")
    func unknownId() {
        #expect {
            try PeekabooAdapter.element(id: "B99", snapshot: Fixture.data("peekaboo-see-4.9.0.json"))
        } throws: { error in
            let error = error as? BigArrowError
            return error?.code == .targetUnresolvable && error?.message.contains("elem_28") == true
        }
    }

    @Test("A 4.9.0 'window list' entry resolves by window_index")
    func windowList() throws {
        let target = try PeekabooAdapter.window(index: 0, list: Fixture.data("peekaboo-window-list-4.9.0.json"))
        #expect(target.shape == .rect(CGRect(x: 306, y: 492, width: 230, height: 408)))
        #expect(target.detail["title"] == "Calculator")
    }

    @Test("A Peekaboo 3.x snapshot without bounds is rejected with the minimum version")
    func boundslessSnapshot() throws {
        let data = try Fixture.data("peekaboo-see-3.0.0-beta3.json")
        #expect(throws: BigArrowError.badInput(PeekabooAdapter.minimumVersionNote)) {
            try PeekabooAdapter.element(id: "elem_9", snapshot: data)
        }
    }

    @Test("The bare MCP shape without the 'data' wrapper is accepted too")
    func bareShape() throws {
        let json = #"{"ui_elements":[{"id":"B1","label":"OK","bounds":{"x":10,"y":20,"width":30,"height":40}}]}"#
        let target = try PeekabooAdapter.element(id: "B1", snapshot: Data(json.utf8))
        #expect(target.shape == .rect(CGRect(x: 10, y: 20, width: 30, height: 40)))
    }

    @Test("Input that is not Peekaboo JSON is bad input")
    func notJSON() {
        #expect(throws: BigArrowError.self) { try PeekabooAdapter.element(id: "B1", snapshot: Data("nope".utf8)) }
        #expect(throws: BigArrowError.self) { try PeekabooAdapter.element(id: "B1", snapshot: Data("{}".utf8)) }
    }
}
