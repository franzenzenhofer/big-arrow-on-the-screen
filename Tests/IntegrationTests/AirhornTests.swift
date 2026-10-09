import AVFoundation
import Foundation
import Testing

/// `--airhorn` plays the wav shipped in the skill folder, so the file must be there and decodable.
@Suite("Airhorn")
struct AirhornTests {
    static var shipped: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("skill/big-arrow/sounds/airhorn.wav")
    }

    @Test("The shipped airhorn decodes and lasts about two seconds")
    func shippedSound() throws {
        let file = try AVAudioFile(forReading: Self.shipped)
        let seconds = Double(file.length) / file.fileFormat.sampleRate
        #expect(seconds > 1 && seconds < 5)
    }

    @Test("--airhorn is accepted and plays nothing with --dry-run")
    func dryRun() throws {
        let result = try BigArrowProcess.run(["point", "--at", "100,100", "--text", "x", "--airhorn", "--dry-run", "--json"])
        #expect(result.code == 0)
        #expect(try result.json()["dryRun"] as? Bool == true)
    }
}
