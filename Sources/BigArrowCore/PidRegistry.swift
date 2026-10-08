import Darwin
import Foundation

/// One live arrow, written to `$TMPDIR/bigarrow/<pid>.json` while it is shown.
public struct ArrowRecord: Codable, Equatable, Sendable {
    public let pid: Int32
    public let text: String
    public let targetX: Double
    public let targetY: Double
    public let display: Int
    public let signFrame: [Double]
    public let direction: String
    public let startedAt: Date

    public init(pid: Int32, text: String, target: CGPoint, display: Int, sign: (frame: CGRect, direction: String), startedAt: Date) {
        self.pid = pid
        self.text = text
        self.targetX = target.x
        self.targetY = target.y
        self.display = display
        self.signFrame = [sign.frame.minX, sign.frame.minY, sign.frame.width, sign.frame.height]
        self.direction = sign.direction
        self.startedAt = startedAt
    }
}

/// Pid files of live arrows. Files whose process is gone are deleted on read.
public struct PidRegistry: Sendable {
    public let directory: URL
    /// Executable name a pid must have to count as a live arrow (pids get reused).
    public static let processName = "bigarrow"

    public init(directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("bigarrow")) {
        self.directory = directory
    }

    public func file(for pid: Int32) -> URL {
        directory.appendingPathComponent("\(pid).json")
    }

    public func write(_ record: ArrowRecord) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: file(for: record.pid), options: .atomic)
    }

    public func read(pid: Int32) -> ArrowRecord? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? Data(contentsOf: file(for: pid))).flatMap { try? decoder.decode(ArrowRecord.self, from: $0) }
    }

    public func remove(pid: Int32) {
        try? FileManager.default.removeItem(at: file(for: pid))
    }

    /// Live arrows, oldest first. Stale and unreadable files are removed.
    public func live() -> [ArrowRecord] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = files.filter { $0.pathExtension == "json" }.compactMap { url -> ArrowRecord? in
            guard let data = try? Data(contentsOf: url),
                  let record = try? decoder.decode(ArrowRecord.self, from: data),
                  Self.isAlive(record.pid) else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            return record
        }
        return records.sorted { $0.startedAt < $1.startedAt }
    }

    /// The pid exists and still runs a `bigarrow` executable.
    public static func isAlive(_ pid: Int32) -> Bool {
        guard pid > 0, kill(pid, 0) == 0 || errno == EPERM else { return false }
        var buffer = [UInt8](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return false }
        return String(bytes: buffer.prefix(Int(length)), encoding: .utf8) == processName
    }
}
