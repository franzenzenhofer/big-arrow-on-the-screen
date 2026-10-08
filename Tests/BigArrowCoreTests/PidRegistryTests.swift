import BigArrowCore
import CoreGraphics
import Foundation
import Testing

@Suite("PidRegistry")
struct PidRegistryTests {
    let registry = PidRegistry(directory: FileManager.default.temporaryDirectory
        .appendingPathComponent("bigarrow-tests-\(UUID().uuidString)"))

    func record(pid: Int32) -> ArrowRecord {
        ArrowRecord(pid: pid, text: "x", target: CGPoint(x: 1, y: 2), display: 1,
                    sign: (CGRect(x: 0, y: 0, width: 10, height: 10), "top"), startedAt: Date())
    }

    @Test("Files of dead processes are ignored and deleted")
    func staleFilesAreRemoved() throws {
        let dead: Int32 = 99_999
        try registry.write(record(pid: dead))
        #expect(FileManager.default.fileExists(atPath: registry.file(for: dead).path))
        #expect(registry.live().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: registry.file(for: dead).path))
    }

    @Test("A live pid that is not a bigarrow process does not count (pids get reused)")
    func reusedPidIsNotAnArrow() throws {
        try registry.write(record(pid: getpid()))
        #expect(registry.live().isEmpty)
        #expect(!PidRegistry.isAlive(getpid()))
    }

    @Test("Unreadable files are removed")
    func garbageIsRemoved() throws {
        try FileManager.default.createDirectory(at: registry.directory, withIntermediateDirectories: true)
        let garbage = registry.directory.appendingPathComponent("123.json")
        try Data("not json".utf8).write(to: garbage)
        #expect(registry.live().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: garbage.path))
    }
}
