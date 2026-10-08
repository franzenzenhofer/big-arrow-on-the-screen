import ArgumentParser
import BigArrowCore
import Foundation

struct InstallSkillCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install-skill",
        abstract: "Install the big-arrow skill for Claude Code and Codex (both by default).",
        discussion: """
        One skill folder serves both agents: ~/.claude/skills/big-arrow (Claude Code) and \
        ~/.agents/skills/big-arrow (Codex). Idempotent; refuses to overwrite files you changed unless --force.
        """
    )

    @Flag(help: "Only install for Claude Code.")
    var claude = false

    @Flag(help: "Only install for Codex.")
    var codex = false

    @Flag(help: "Overwrite skill files that differ from the shipped ones.")
    var force = false

    @Option(help: help("The skill folder to install (default: the one shipped next to the executable).", "path"))
    var source: String?

    func run() throws {
        let folder = try source.map { URL(fileURLWithPath: $0) } ?? SkillLocator.skillFolder()
        let agents: [SkillAgent] = claude == codex ? SkillAgent.allCases : (claude ? [.claude] : [.codex])
        for agent in agents {
            let installer = SkillInstaller(source: folder, destination: agent.destination)
            let outcome = try installer.install(overwrite: force ? .always : .whenUnchanged)
            Output.print("bigarrow: \(agent.rawValue) skill \(outcome)")
        }
    }
}

enum SkillAgent: String, CaseIterable {
    case claude = "Claude Code"
    case codex = "Codex"

    /// Codex reads user skills from ~/.agents/skills (https://learn.chatgpt.com/docs/build-skills).
    var destination: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .claude: return home.appendingPathComponent(".claude/skills/big-arrow")
        case .codex: return home.appendingPathComponent(".agents/skills/big-arrow")
        }
    }
}

enum OverwritePolicy {
    case whenUnchanged
    case always
}

/// Copies every file of the shipped skill folder. A destination that is a symlink to the
/// shipped folder (a developer checkout) already counts as installed.
struct SkillInstaller {
    let source: URL
    let destination: URL

    func install(overwrite: OverwritePolicy) throws -> String {
        let files = try relativeFiles()
        if destination.resolvingSymlinksInPath().standardizedFileURL == source.resolvingSymlinksInPath().standardizedFileURL {
            return "already linked at \(destination.path), nothing changed"
        }
        let changed = files.filter { contents(destination, $0) != contents(source, $0) }
        if changed.isEmpty { return "already installed at \(destination.path), nothing changed" }
        let modified = changed.filter { contents(destination, $0) != nil }
        if !modified.isEmpty, overwrite == .whenUnchanged {
            let names = modified.joined(separator: ", ")
            throw BigArrowError.badInput("\(destination.path) has changed files (\(names)); rerun with --force to replace them")
        }
        for file in changed {
            let target = destination.appendingPathComponent(file)
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents(source, file)?.write(to: target)
        }
        return (modified.isEmpty ? "installed at " : "updated at ") + destination.path
    }

    func relativeFiles() throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey]) else {
            throw BigArrowError.badInput("cannot read the skill folder \(source.path)")
        }
        let base = source.resolvingSymlinksInPath().path + "/"
        let files = enumerator.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map { $0.resolvingSymlinksInPath().path.replacingOccurrences(of: base, with: "") }
        guard files.contains("SKILL.md") else { throw BigArrowError.badInput("no SKILL.md in \(source.path)") }
        return files.sorted()
    }

    func contents(_ folder: URL, _ file: String) -> Data? {
        FileManager.default.contents(atPath: folder.appendingPathComponent(file).path)
    }
}

/// Finds the shipped skill folder: `<prefix>/share/bigarrow/skill/big-arrow` for Homebrew,
/// or `<checkout>/skill/big-arrow` when run from a SwiftPM build directory.
enum SkillLocator {
    static let searchDepth = 6

    static func skillFolder() throws -> URL {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            throw BigArrowError.badInput("cannot find the bigarrow executable; pass --source")
        }
        var directory = executable.deletingLastPathComponent()
        for _ in 0..<searchDepth {
            for candidate in ["share/bigarrow/skill/big-arrow", "skill/big-arrow"] {
                let folder = directory.appendingPathComponent(candidate)
                if FileManager.default.fileExists(atPath: folder.appendingPathComponent("SKILL.md").path) { return folder }
            }
            directory = directory.deletingLastPathComponent()
        }
        throw BigArrowError.badInput("cannot find the shipped skill folder near \(executable.path); pass --source")
    }
}
