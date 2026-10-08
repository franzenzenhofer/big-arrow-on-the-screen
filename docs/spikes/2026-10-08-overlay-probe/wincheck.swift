import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w["kCGWindowOwnerName"] as? String) == "probe" {
    print("owner=probe layer=\(w["kCGWindowLayer"] ?? "?") bounds=\(w["kCGWindowBounds"] ?? "?") alpha=\(w["kCGWindowAlpha"] ?? "?")")
}
