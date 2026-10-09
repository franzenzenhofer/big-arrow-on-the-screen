import BigArrowCore
import BigArrowTargeting
import Foundation

/// Ties an arrow to the app its target is in: while another app's window covers the target,
/// the arrow hides, and it comes back once the target is visible again. Needs no permission.
@MainActor
final class HomeBinder {
    static let interval: TimeInterval = 0.25

    private weak var session: PointSession?
    private let app: String
    private var timer: Timer?

    init(session: PointSession, app: String) {
        self.session = session
        self.app = app
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        guard let session else { return }
        let pids = Set(WindowMatcher.apps(matching: app, in: WindowTarget.runningApps()).map(\.pid))
        let anchor = session.planned.resolved.shape.anchor
        let covered = WindowMatcher.isCovered(anchor, owners: pids, windows: WindowTarget.onScreenWindows())
        session.setHidden(covered, because: .covered)
    }
}

/// Ends the arrow when the agent process that drew it exits, so no arrow outlives its session.
@MainActor
final class OwnerWatch {
    private let source: DispatchSourceProcess

    init(pid: Int32, onExit: @escaping @MainActor () -> Void) {
        source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { onExit() } }
        source.resume()
    }

    func stop() {
        source.cancel()
    }
}
