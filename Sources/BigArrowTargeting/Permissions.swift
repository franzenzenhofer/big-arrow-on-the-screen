import ApplicationServices
import BigArrowCore
import CoreGraphics

/// The privacy permissions some targets need. Drawing needs none of them.
public enum Permission: String, CaseIterable, Sendable, Codable {
    case accessibility
    case screenRecording = "screen-recording"

    public var isGranted: Bool {
        switch self {
        case .accessibility: AXIsProcessTrusted()
        case .screenRecording: CGPreflightScreenCaptureAccess()
        }
    }

    public var settingsPane: String {
        switch self {
        case .accessibility: "System Settings > Privacy & Security > Accessibility"
        case .screenRecording: "System Settings > Privacy & Security > Screen & System Audio Recording"
        }
    }

    public var settingsURL: String {
        switch self {
        case .accessibility: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }
    }

    var displayName: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen Recording"
        }
    }

    /// Exit 4 with a message that names the app the human must grant, never `bigarrow` itself.
    public func missing(for feature: String) -> BigArrowError {
        .permission(
            "\(feature) needs \(displayName) permission for \(ResponsibleProcess.describeForMessage()), "
                + "not for bigarrow: turn it on in \(settingsPane), then restart that app. "
                + "Run 'bigarrow doctor' to check."
        )
    }

    public func require(for feature: String) throws {
        guard isGranted else { throw missing(for: feature) }
    }

    /// Shows the system prompt that adds the responsible app to the Accessibility list.
    public static func requestAccessibility() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
