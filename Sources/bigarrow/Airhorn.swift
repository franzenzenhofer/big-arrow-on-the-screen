import AppKit
import BigArrowCore
import Foundation

/// `--airhorn`: plays the airhorn shipped in the skill folder once, at the current output volume.
/// It never changes the system volume or the mute setting: a muted Mac stays silent.
@MainActor
enum Airhorn {
    static let file = "sounds/airhorn.wav"

    static func url() throws -> URL {
        try SkillLocator.skillFolder().appendingPathComponent(file)
    }

    /// Returns the playing sound, which must be kept alive until it ends; nil (with a warning) if it cannot play.
    static func play() -> NSSound? {
        do {
            let url = try url()
            guard let sound = NSSound(contentsOf: url, byReference: true), sound.play() else {
                Output.printError("bigarrow: could not play \(url.path)")
                return nil
            }
            return sound
        } catch let error as BigArrowError {
            Output.printError("bigarrow: no airhorn: \(error.message)")
        } catch {
            Output.printError("bigarrow: no airhorn: \(error.localizedDescription)")
        }
        return nil
    }
}
