// list-displays: print online displays (CoreGraphics, global top-left points) and NSScreen.screens.
import AppKit

var count: UInt32 = 0
CGGetOnlineDisplayList(0, nil, &count)
var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
CGGetOnlineDisplayList(count, &ids, &count)
print("online displays: \(count)")
for id in ids.prefix(Int(count)) {
    let bounds = CGDisplayBounds(id)
    print("  id=\(id) bounds=\(bounds) main=\(CGDisplayIsMain(id)) mirrors=\(CGDisplayMirrorsDisplay(id))")
}
print("NSScreen.screens: \(NSScreen.screens.count)")
for screen in NSScreen.screens {
    print("  \(screen.localizedName) frame=\(screen.frame) scale=\(screen.backingScaleFactor)")
}
