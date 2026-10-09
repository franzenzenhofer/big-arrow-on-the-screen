import BigArrowCore
import CoreGraphics
import Testing

@Suite("Effects")
struct EffectsTests {
    @Test("--shake takes a number or a name, case-insensitive")
    func shakeLevels() throws {
        #expect(try ShakeLevel.parse("1") == .mild)
        #expect(try ShakeLevel.parse("insistent") == .insistent)
        #expect(try ShakeLevel.parse(" ANGRY ") == .angry)
        #expect(try ShakeLevel.parse("4") == .topiramate)
        #expect(try ShakeLevel.parse("topiramate") == .topiramate)
    }

    @Test("Any other shake is bad input that lists the levels", arguments: ["0", "5", "furious", ""])
    func badShake(raw: String) {
        let levels = "1 (mild), 2 (insistent), 3 (angry), 4 (topiramate)"
        #expect(throws: BigArrowError.badInput("shake '\(raw)' is not one of \(levels)")) {
            try ShakeLevel.parse(raw)
        }
    }

    @Test("Each shake level is stronger and faster than the one before")
    func shakeEscalates() {
        for (calmer, wilder) in zip(ShakeLevel.allCases, ShakeLevel.allCases.dropFirst()) {
            #expect(wilder.amplitude > calmer.amplitude)
            #expect(wilder.jolt < calmer.jolt)
        }
    }

    @Test("Samples along a line are evenly spaced, with direction and share")
    func lineSamples() {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 100, y: 0))
        let samples = PathSampler.samples(along: path, spacing: 20)
        #expect(samples.map(\.point.x) == [10, 30, 50, 70, 90])
        #expect(samples.allSatisfy { $0.tangent == CGPoint(x: 1, y: 0) && $0.point.y == 0 })
        #expect(samples.map(\.share) == [0.1, 0.3, 0.5, 0.7, 0.9])
    }

    @Test("Curves are followed: samples of a quad curve stay between its ends and on its side")
    func curveSamples() throws {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: 200, y: 0), control: CGPoint(x: 100, y: 100))
        let samples = PathSampler.samples(along: path, spacing: 25)
        #expect(samples.count >= 8)
        #expect(samples.allSatisfy { $0.point.x > 0 && $0.point.x < 200 && $0.point.y > 0 && $0.point.y <= 50 })
        let middle = try #require(samples.min { abs($0.point.x - 100) < abs($1.point.x - 100) })
        #expect(abs(middle.tangent.y) < 0.2)
    }

    @Test("Jitter is repeatable and stays in 0..<1")
    func jitter() {
        let values = (0..<200).map { PathSampler.jitter($0, salt: 3) }
        #expect(values == (0..<200).map { PathSampler.jitter($0, salt: 3) })
        #expect(values.allSatisfy { $0 >= 0 && $0 < 1 })
        #expect(Set(values.map { Int($0 * 10) }).count == 10)
    }
}
