import BigArrowCore
import CoreGraphics
import Testing

@Suite("Parsing")
struct ParsingTests {
    @Test("Points and rects parse from comma-separated numbers")
    func numbers() throws {
        #expect(try NumberListParser.point("760,500") == CGPoint(x: 760, y: 500))
        #expect(try NumberListParser.point(" -12.5 , 3 ") == CGPoint(x: -12.5, y: 3))
        #expect(try NumberListParser.rect("400,300,200,80") == CGRect(x: 400, y: 300, width: 200, height: 80))
    }

    @Test("Malformed numbers are bad input", arguments: ["760", "760,500,1", "a,b", "760;500", "", "nan,1"])
    func badPoints(raw: String) {
        #expect(throws: BigArrowError.badInput("'\(raw)' is not 2 comma-separated numbers, example: 760,500")) {
            try NumberListParser.point(raw)
        }
    }

    @Test("Rects need a positive size")
    func badRect() {
        #expect(throws: BigArrowError.self) { try NumberListParser.rect("1,2,0,5") }
        #expect(throws: BigArrowError.self) { try NumberListParser.rect("1,2,3") }
    }

    @Test("Colours accept presets and hex, anything else names the accepted formats")
    func colours() throws {
        #expect(try ArrowColor.parse("blue") == ArrowColor.parse("#0A84FF"))
        #expect(try ArrowColor.parse("ff0000") == ArrowColor(red: 1, green: 0, blue: 0))
        #expect {
            try ArrowColor.parse("rainbow")
        } throws: { error in
            (error as? BigArrowError)?.message.contains(ArrowColor.accepted) == true
        }
        #expect(throws: BigArrowError.self) { try ArrowColor.parse("#12345") }
        #expect(try ArrowColor.parse("#f31") == ArrowColor.parse("FF3311"))
    }

    @Test("Every preset parses, and light colours get a dark outline and text", arguments: ArrowColor.presets.map(\.name))
    func presets(name: String) throws {
        let color = try ArrowColor.parse(name)
        let expectDark = ["yellow", "white"].contains(name)
        #expect(color.isLight == expectDark)
        #expect(color.contrast.isLight == !expectDark)
    }

    @Test("Sizes, styles and sides parse case-insensitively")
    func enums() throws {
        #expect(try ArrowSize.parse("l") == .large)
        #expect(try ArrowStyle.parse("RING") == .ring)
        #expect(try ApproachDirection.parse("auto") == nil)
        #expect(try ApproachDirection.parse("Top-Left") == .topLeft)
        #expect(throws: BigArrowError.self) { try ArrowSize.parse("XL") }
        #expect(throws: BigArrowError.self) { try ApproachDirection.parse("north") }
    }

    @Test("Window queries split app and title at the first colon")
    func windowQuery() throws {
        let query = try WindowQuery("Google Chrome:Inbox: 3 new")
        #expect(query.app == "Google Chrome")
        #expect(query.title == "Inbox: 3 new")
        #expect(try WindowQuery("Safari").title == nil)
        #expect(throws: BigArrowError.self) { try WindowQuery(":title") }
    }

    @Test("Window anchors are points inside the window")
    func anchors() {
        let rect = CGRect(x: 100, y: 50, width: 800, height: 600)
        #expect(WindowAnchor.center.point(in: rect) == CGPoint(x: 500, y: 350))
        #expect(WindowAnchor.title.point(in: rect) == CGPoint(x: 500, y: 64))
        #expect(WindowAnchor.bottomRight.point(in: rect) == CGPoint(x: 880, y: 630))
    }
}
