import Darwin
import Foundation

/// The app that macOS attributes this process's privacy permissions to: the outermost `.app`
/// in the parent chain (Terminal, iTerm2, Ghostty, VS Code, Claude). Accessibility granted to
/// that app is what `bigarrow` inherits. https://developer.apple.com/forums/thread/678819
public struct ResponsibleApp: Codable, Equatable, Sendable {
    public let name: String
    public let bundleID: String?
    public let path: String
    public let pid: Int32
}

public enum ResponsibleProcess {
    public static func find(startingAt pid: Int32 = getpid()) -> ResponsibleApp? {
        var current = pid
        var visited = Set<Int32>()
        while current > 1, !visited.contains(current) {
            visited.insert(current)
            if let path = executablePath(current), let app = appBundle(in: path) {
                return describe(bundlePath: app, pid: current)
            }
            current = parent(of: current)
        }
        return nil
    }

    /// Human readable form for error messages.
    public static func describeForMessage() -> String {
        guard let app = find() else {
            return "the app that runs this shell (no .app found in the parent chain, e.g. under tmux or SSH)"
        }
        return "\(app.name) (\(app.bundleID ?? app.path))"
    }

    static func executablePath(_ pid: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(bytes: buffer.prefix(Int(length)), encoding: .utf8)
    }

    static func parent(of pid: Int32) -> Int32 {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return 0 }
        return info.kp_eproc.e_ppid
    }

    /// `/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/...` gives the outer app.
    static func appBundle(in path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    static func describe(bundlePath: String, pid: Int32) -> ResponsibleApp {
        let bundle = Bundle(path: bundlePath)
        let info = bundle?.infoDictionary
        let fallbackName = URL(fileURLWithPath: bundlePath).deletingPathExtension().lastPathComponent
        let name = (info?["CFBundleDisplayName"] ?? info?["CFBundleName"]) as? String ?? fallbackName
        return ResponsibleApp(name: name, bundleID: bundle?.bundleIdentifier, path: bundlePath, pid: pid)
    }
}
