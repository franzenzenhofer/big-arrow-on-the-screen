import Foundation

/// The agent session an arrow belongs to. A detached arrow inherits its parent's environment, so
/// it knows the agent's process (it ends when that process exits) and session id (a prompt hook
/// clears exactly that session's arrows). Claude Code exports both; other agents set the
/// `BIGARROW_*` variables.
public struct ArrowOwner: Codable, Equatable, Sendable {
    public let pid: Int32?
    public let session: String?

    public static let pidKeys = ["BIGARROW_OWNER_PID", "CLAUDE_PID"]
    public static let sessionKeys = ["BIGARROW_SESSION", "CLAUDE_CODE_SESSION_ID"]

    public init(pid: Int32?, session: String?) {
        self.pid = pid
        self.session = session
    }

    /// The first set key wins; a pid that is not a positive number is ignored.
    public static func from(environment: [String: String]) -> ArrowOwner {
        let pid = firstValue(pidKeys, environment).flatMap(Int32.init).flatMap { $0 > 0 ? $0 : nil }
        return ArrowOwner(pid: pid, session: firstValue(sessionKeys, environment))
    }

    public static var current: ArrowOwner {
        from(environment: ProcessInfo.processInfo.environment)
    }

    static func firstValue(_ keys: [String], _ environment: [String: String]) -> String? {
        keys.lazy.compactMap { environment[$0]?.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    }
}
