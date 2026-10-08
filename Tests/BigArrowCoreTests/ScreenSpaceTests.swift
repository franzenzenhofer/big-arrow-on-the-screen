import BigArrowCore
import CoreGraphics
import Testing

@Suite("ScreenSpace")
struct ScreenSpaceTests {
    let space = TestDisplays.threeDisplays

    @Test("AppKit frames flip into global top-left points against the primary display height")
    func flipsFrames() {
        #expect(space.displays.map(\.frame) == [
            CGRect(x: 0, y: 0, width: 1512, height: 982),
            CGRect(x: 1512, y: -98, width: 1920, height: 1080),
            CGRect(x: 3432, y: -98, width: 1920, height: 1080)
        ])
        #expect(space.displays[0].visibleFrame == CGRect(x: 0, y: 33, width: 1512, height: 949))
        #expect(space.displays.map(\.scale) == [2, 1, 1])
    }

    @Test("Flipping a rect twice gives the rect back")
    func flipRoundTrip() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        let once = ScreenSpace.flip(rect, primaryHeight: 982)
        #expect(once == CGRect(x: 10, y: 922, width: 30, height: 40))
        #expect(ScreenSpace.flip(once, primaryHeight: 982) == rect)
    }

    @Test("Points resolve to the display that contains them, including negative y")
    func containment() throws {
        #expect(try space.display(containing: CGPoint(x: 760, y: 500)).index == 0)
        #expect(try space.display(containing: CGPoint(x: 2000, y: -50)).index == 1)
        #expect(try space.display(containing: CGPoint(x: 5351, y: 981)).index == 2)
    }

    @Test("Points on a shared edge belong to the right-hand display, deterministically")
    func boundary() throws {
        #expect(try space.display(containing: CGPoint(x: 1512, y: 10)).index == 1)
        #expect(try space.display(containing: CGPoint(x: 1511.99, y: 10)).index == 0)
        #expect(try space.display(containing: CGPoint(x: 3432, y: 10)).index == 2)
    }

    @Test("A point outside every display is bad input (exit 2)")
    func outside() {
        for point in [CGPoint(x: 99999, y: 0), CGPoint(x: 100, y: -50), CGPoint(x: -1, y: 10)] {
            #expect {
                try space.display(containing: point)
            } throws: { error in
                let error = error as? BigArrowError
                return error?.code == .badInput && error?.message.contains("point is outside every display") == true
            }
        }
    }

    @Test("Displays are numbered from 1 and unknown numbers are bad input")
    func numbering() throws {
        #expect(try space.display(number: 2).id == 2)
        #expect(throws: BigArrowError.self) { try space.display(number: 4) }
        #expect(throws: BigArrowError.self) { try space.display(number: 0) }
    }

    @Test("A single display works the same way")
    func single() throws {
        let single = TestDisplays.singleDisplay
        #expect(single.displays.count == 1)
        #expect(try single.display(containing: CGPoint(x: 0, y: 0)).index == 0)
        #expect(throws: BigArrowError.self) { try single.display(containing: CGPoint(x: 1512, y: 0)) }
    }

    @Test("Local coordinates are relative to the display's top-left corner")
    func local() {
        let second = space.displays[1]
        #expect(second.local(CGPoint(x: 1612, y: 2)) == CGPoint(x: 100, y: 100))
        #expect(second.localBounds == CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }
}
