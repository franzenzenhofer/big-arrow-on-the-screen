import BigArrowCore
import CoreGraphics
import Foundation

/// A passive, listen-only event tap for left mouse downs. It never consumes or alters events.
@MainActor
public final class ClickWatcher {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let onClick: @MainActor (CGPoint) -> Void

    /// Throws exit 4 when macOS refuses the tap (the responsible app lacks the permission).
    public init(onClick: @escaping @MainActor (CGPoint) -> Void) throws {
        self.onClick = onClick
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: clickCallback, userInfo: context
        ) else {
            throw Permission.accessibility.missing(for: "Dismissing on click (--until-click)")
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func handle(_ type: CGEventType, location: CGPoint) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            onClick(location)
        default:
            return
        }
    }

    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }
}

/// CGEvent locations are global top-left points, the same space as every target.
private func clickCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, context: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let context else { return Unmanaged.passUnretained(event) }
    let location = event.location
    let watcher = Unmanaged<ClickWatcher>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { watcher.handle(type, location: location) }
    return Unmanaged.passUnretained(event)
}
