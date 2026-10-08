import CoreGraphics
import Foundation

/// Calls back on the main queue after the display configuration changed (plug, unplug, mirror,
/// resolution). Works without the AppKit event loop.
@MainActor
public final class DisplayWatcher {
    private let onChange: @MainActor () -> Void

    public init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        CGDisplayRegisterReconfigurationCallback(displayCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    func changed() {
        onChange()
    }

    /// IDs of the displays that are active right now.
    public static func activeDisplayIDs() -> [UInt32] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }
}

/// Only the final notification of a reconfiguration matters, not the "begin" one.
private func displayCallback(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags, context: UnsafeMutableRawPointer?) {
    guard let context, !flags.contains(.beginConfigurationFlag) else { return }
    let watcher = Unmanaged<DisplayWatcher>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async {
        MainActor.assumeIsolated { watcher.changed() }
    }
}
