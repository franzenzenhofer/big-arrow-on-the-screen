import AppKit
import BigArrowCore

/// What `bigarrow doctor` reports: permissions, who owns them, displays, Peekaboo, macOS.
public struct DoctorReport: Codable, Sendable {
    public struct DisplayLine: Codable, Sendable {
        public let number: Int
        public let id: UInt32
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
        public let scale: Double
    }

    public var ok: Bool
    public let version: String
    public let macOS: String
    public let accessibility: Bool
    public let screenRecording: Bool
    public let responsibleApp: ResponsibleApp?
    public let displays: [DisplayLine]
    public let screensHaveSeparateSpaces: Bool
    public let peekaboo: String?
    public var drawingNeedsPermission = false
    public var missing: [String]
}

@MainActor
public enum Doctor {
    public static func report(screens: ScreenSpace, required: [Permission]) -> DoctorReport {
        let missing = required.filter { !$0.isGranted }.map(\.rawValue)
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return DoctorReport(
            ok: missing.isEmpty,
            version: BigArrowVersion.current,
            macOS: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            accessibility: Permission.accessibility.isGranted,
            screenRecording: Permission.screenRecording.isGranted,
            responsibleApp: ResponsibleProcess.find(),
            displays: screens.displays.map(line),
            screensHaveSeparateSpaces: NSScreen.screensHaveSeparateSpaces,
            peekaboo: peekabooVersion(),
            missing: missing
        )
    }

    static func line(_ display: Display) -> DoctorReport.DisplayLine {
        DoctorReport.DisplayLine(
            number: display.index + 1, id: display.id,
            x: display.frame.minX, y: display.frame.minY,
            width: display.frame.width, height: display.frame.height, scale: display.scale
        )
    }

    /// `peekaboo --version` when peekaboo is on PATH, nil otherwise.
    static func peekabooVersion() -> String? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":")
        guard let path = paths.map({ "\($0)/peekaboo" }).first(where: FileManager.default.isExecutableFile) else {
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "installed at \(path), --version failed" }
        process.waitUntilExit()
        let output = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        return output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "installed at \(path), unreadable --version"
    }
}
