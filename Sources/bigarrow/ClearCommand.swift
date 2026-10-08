import ArgumentParser
import BigArrowCore
import Foundation

struct ClearCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Remove the newest live arrow (--all: every arrow, --pid: one arrow). Alias: stop.",
        discussion: "Run it once the human has acted. Arrows fade out and their processes exit 0.",
        aliases: ["stop"]
    )

    @Flag(help: "Remove every live arrow.")
    var all = false

    @Option(help: ArgumentHelp("Remove the arrow with this pid.", valueName: "pid"))
    var pid: Int32?

    @Flag(help: "Print a JSON result.")
    var json = false

    struct Result: Codable {
        var ok = true
        let cleared: [Int32]
    }

    static let waitLimit: TimeInterval = 1
    static let pollInterval: useconds_t = 5_000

    func run() throws {
        let live = PidRegistry().live()
        let chosen = try choose(from: live)
        chosen.forEach { kill($0.pid, SIGTERM) }
        waitUntilGone(chosen.map(\.pid))
        let pids = chosen.map(\.pid)
        if json {
            Output.json(Result(cleared: pids))
        } else {
            Output.print(pids.isEmpty ? "bigarrow: no live arrows" : "bigarrow: cleared \(pids.map(String.init).joined(separator: ", "))")
        }
    }

    func choose(from live: [ArrowRecord]) throws -> [ArrowRecord] {
        if let pid {
            guard let record = live.first(where: { $0.pid == pid }) else {
                throw BigArrowError.unresolvable("no live arrow with pid \(pid)")
            }
            return [record]
        }
        if all { return live }
        return live.last.map { [$0] } ?? []
    }

    /// Returns once every process has exited, at most after `waitLimit`.
    func waitUntilGone(_ pids: [Int32]) {
        let deadline = Date().addingTimeInterval(Self.waitLimit)
        while Date() < deadline, pids.contains(where: PidRegistry.isAlive) {
            usleep(Self.pollInterval)
        }
    }
}
