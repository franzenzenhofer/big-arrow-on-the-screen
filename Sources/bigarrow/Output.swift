import BigArrowCore
import Foundation

/// Every line the CLI writes goes through here: results to stdout, errors to stderr.
enum Output {
    static func print(_ line: String) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }

    static func printError(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    static func json<T: Encodable>(_ value: T) {
        print(JSONOutput.encode(value))
    }

    /// One line on stderr (JSON with `--json`), then the error's exit code.
    static func fail(_ error: BigArrowError, json: Bool) -> Never {
        let line = error.message.replacingOccurrences(of: "\n", with: " ")
        if json {
            printError(JSONOutput.encode(ErrorResult(BigArrowError(error.code, line))))
        } else {
            printError("bigarrow: \(line)")
        }
        exit(error.code.rawValue)
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
