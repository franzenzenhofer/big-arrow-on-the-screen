import BigArrowCore
import BigArrowOverlay
import BigArrowTargeting
import Foundation

/// The one target `point` was asked for, before resolution.
enum TargetSpec {
    case coordinate(CGPoint, display: Int?)
    case rect(CGRect, display: Int?)
    case mouse
    case window(WindowQuery, WindowAnchor)
    case element(ElementQuery, app: String?)
    case peekabooElement(id: String, snapshot: Data)
    case peekabooWindow(index: Int, list: Data)

    /// The app `--raise` brings to the front, and the window title to raise with it.
    var raiseApp: (app: String, windowTitle: String?)? {
        switch self {
        case .window(let query, _): (query.app, query.title)
        case .element(_, let app?): (app, nil)
        default: nil
        }
    }

    /// Only targets that can move are re-resolved by `--follow`.
    var isFollowable: Bool {
        switch self {
        case .window, .element: true
        default: false
        }
    }

    @MainActor
    func resolve(screens: ScreenSpace) throws -> ResolvedTarget {
        switch self {
        case .coordinate(let point, let display):
            let global = try Self.global(point, display: display, screens: screens)
            return ResolvedTarget(shape: .point(global), source: "coordinate")
        case .rect(let rect, let display):
            let origin = try Self.global(rect.origin, display: display, screens: screens)
            return ResolvedTarget(shape: .rect(CGRect(origin: origin, size: rect.size)), source: "rect")
        case .mouse:
            return ResolvedTarget(shape: .point(ScreenReader.mouseLocation()), source: "mouse")
        case .window(let query, let anchor):
            return try WindowTarget.resolve(query, anchor: anchor)
        case .element(let query, let app):
            return try ElementTarget.resolve(query, app: app, screens: screens)
        case .peekabooElement(let id, let snapshot):
            return try PeekabooAdapter.element(id: id, snapshot: snapshot)
        case .peekabooWindow(let index, let list):
            return try PeekabooAdapter.window(index: index, list: list)
        }
    }

    /// With `--display N`, coordinates are relative to that display's top-left corner.
    static func global(_ point: CGPoint, display: Int?, screens: ScreenSpace) throws -> CGPoint {
        guard let display else { return point }
        let frame = try screens.display(number: display).frame
        let global = CGPoint(x: frame.minX + point.x, y: frame.minY + point.y)
        guard frame.contains(global) else {
            throw BigArrowError.badInput(
                "point \(Int(point.x)),\(Int(point.y)) is outside display \(display) (\(Int(frame.width))x\(Int(frame.height)))"
            )
        }
        return global
    }
}
