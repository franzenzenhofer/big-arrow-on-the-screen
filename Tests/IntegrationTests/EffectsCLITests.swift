import AppKit
import Foundation
import Testing

/// `--rainbow`, `--drip`, `--flames` and `--shake` through the real binary, offscreen (`--png`, `--dry-run`).
@Suite("Effects CLI")
struct EffectsCLITests {
    static func render(_ extra: [String]) throws -> NSBitmapImageRep {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("bigarrow-fx-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: file) }
        let result = try BigArrowProcess.run(["point", "--at", "760,500", "--text", "Franz, click HERE", "--png", file.path] + extra)
        try #require(result.code == 0, "bigarrow failed: \(result.stderr)")
        return try #require(NSBitmapImageRep(data: Data(contentsOf: file)))
    }

    /// Hues (in twelfths) of the opaque, saturated pixels, sampled on a grid.
    static func hues(_ rep: NSBitmapImageRep) throws -> Set<Int> {
        var hues = Set<Int>()
        for x in stride(from: 0, to: rep.pixelsWide, by: 6) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 6) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                      color.alphaComponent > 0.95, color.saturationComponent > 0.6, color.brightnessComponent > 0.6 else { continue }
                hues.insert(Int(color.hueComponent * 12) % 12)
            }
        }
        return hues
    }

    @Test("Every effect flag is accepted, shake by number or name")
    func flags() throws {
        for shake in ["1", "insistent", "3", "topiramate"] {
            let arguments = ["point", "--at", "760,500", "--text", "x", "--rainbow", "--drip", "--flames", "--shake", shake, "--dry-run"]
            #expect(try BigArrowProcess.run(arguments).code == 0)
        }
        #expect(try BigArrowProcess.run(["point", "--at", "760,500", "--text", "x", "--shake", "11", "--dry-run"]).code == 2)
    }

    @Test("--rainbow paints the arrow in many hues; the default arrow has one")
    func rainbow() throws {
        #expect(try Self.hues(Self.render([])).count <= 2)
        #expect(try Self.hues(Self.render(["--rainbow"])).count >= 8)
    }

    @Test("--drip hangs paint below the sign, so the picture grows downwards")
    func drip() throws {
        let plain = try Self.render([])
        let dripping = try Self.render(["--drip"])
        #expect(dripping.pixelsHigh > plain.pixelsHigh)
        #expect(dripping.pixelsWide == plain.pixelsWide)
    }
}
