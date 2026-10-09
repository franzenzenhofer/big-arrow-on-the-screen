import BigArrowCore
import Darwin
import Foundation

/// `--detach`: re-runs the same command without `--detach` in a new session with /dev/null
/// for stdin, stdout and stderr, so an agent's shell call returns at once and is never held
/// open by the child's pipes. Returns once the child shows its arrow.
struct Detacher {
    let config: PointConfig
    static let readyTimeout: TimeInterval = 3
    static let pollInterval: useconds_t = 5_000
    static let snapshotPrefix = "snapshot-"

    /// Starts the child and returns its own record of what it drew, which is the truth even if
    /// the screen changed (Dock shown, display added) between the parent's plan and the child's.
    func spawn() throws -> ArrowRecord {
        guard let executable = Bundle.main.executablePath else {
            throw BigArrowError.badInput("cannot find the bigarrow executable to detach")
        }
        let arguments = try childArguments(executable: executable)
        let pid = try Self.posixSpawn(executable, arguments)
        try waitUntilShown(pid)
        guard let record = PidRegistry().read(pid: pid) else {
            throw BigArrowError.unresolvable("the detached arrow (pid \(pid)) wrote no readable pid file")
        }
        return record
    }

    func childArguments(executable: String) throws -> [String] {
        var arguments = [executable, "point"] + Self.optionsWithoutDuration(CommandLine.arguments.dropFirst(2))
        arguments += ["--duration", String(config.duration)]
        // The parent already raised the target's app; raising twice only costs time.
        if !arguments.contains("--no-raise") { arguments.append("--no-raise") }
        if let data = config.stdinSnapshot {
            let file = PidRegistry().directory.appendingPathComponent("\(Self.snapshotPrefix)\(UUID().uuidString).json")
            try FileManager.default.createDirectory(at: PidRegistry().directory, withIntermediateDirectories: true)
            try data.write(to: file)
            arguments += ["--snapshot", file.path]
        }
        return arguments
    }

    /// The child is always a foreground `point`; `--detach` is dropped and the resolved duration
    /// is passed explicitly, because `start` and `point` default to different durations.
    static func optionsWithoutDuration(_ arguments: ArraySlice<String>) -> [String] {
        var result: [String] = []
        var skipNext = false
        for argument in arguments {
            if skipNext {
                skipNext = false
            } else if argument == "--duration" {
                skipNext = true
            } else if argument != "--detach", !argument.hasPrefix("--duration=") {
                result.append(argument)
            }
        }
        return result
    }

    static func posixSpawn(_ executable: String, _ arguments: [String]) throws -> Int32 {
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer {
            posix_spawn_file_actions_destroy(&actions)
            posix_spawnattr_destroy(&attributes)
        }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID))
        let argv = arguments.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        var pid: pid_t = 0
        let status = posix_spawn(&pid, executable, &actions, &attributes, argv, environ)
        guard status == 0 else {
            throw BigArrowError.badInput("could not start the detached arrow: \(String(cString: strerror(status)))")
        }
        return pid
    }

    /// The child writes its pid file right after the panel is on screen.
    func waitUntilShown(_ pid: Int32) throws {
        let file = PidRegistry().file(for: pid).path
        let deadline = Date().addingTimeInterval(Self.readyTimeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: file) { return }
            var status: Int32 = 0
            if waitpid(pid, &status, WNOHANG) == pid {
                let code = (status >> 8) & 0xFF
                let exitCode = ExitCode(rawValue: code) ?? .targetUnresolvable
                throw BigArrowError(exitCode, "the detached arrow exited with code \(code) before showing")
            }
            usleep(Self.pollInterval)
        }
        throw BigArrowError.unresolvable("the detached arrow (pid \(pid)) did not show within \(Int(Self.readyTimeout)) s")
    }
}
