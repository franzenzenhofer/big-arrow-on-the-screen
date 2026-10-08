import Foundation

/// Process exit codes, the contract every agent can rely on.
public enum ExitCode: Int32, Sendable, Codable {
    case ok = 0
    case badInput = 2
    case targetUnresolvable = 3
    case permissionMissing = 4
}

/// The one error type the CLI turns into an exit code and a one-line message.
public struct BigArrowError: Error, Equatable, Sendable, CustomStringConvertible {
    public let code: ExitCode
    public let message: String

    public init(_ code: ExitCode, _ message: String) {
        self.code = code
        self.message = message
    }

    public static func badInput(_ message: String) -> BigArrowError {
        BigArrowError(.badInput, message)
    }

    public static func unresolvable(_ message: String) -> BigArrowError {
        BigArrowError(.targetUnresolvable, message)
    }

    public static func permission(_ message: String) -> BigArrowError {
        BigArrowError(.permissionMissing, message)
    }

    public var description: String { message }
}
