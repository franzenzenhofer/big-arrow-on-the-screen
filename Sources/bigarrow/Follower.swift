import BigArrowCore
import BigArrowOverlay
import Foundation

/// `--follow`: re-resolves a window or element target every 250 ms and moves the arrow.
/// A target that stays gone for 2 s ends the arrow, unless it is sticky (--duration 0).
@MainActor
final class Follower {
    static let interval: TimeInterval = 0.25
    static let goneLimit: TimeInterval = 2
    /// Smaller moves than this are noise.
    static let moveThreshold: CGFloat = 0.5

    private weak var session: PointSession?
    private var timer: Timer?
    private var goneSince: Date?

    init(session: PointSession) {
        self.session = session
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
        let screens = ScreenReader.current()
        guard let resolved = try? session.config.target.resolve(screens: screens),
              let next = try? session.planner.plan(resolved, screens: screens) else {
            targetMissing(session)
            return
        }
        if goneSince != nil {
            goneSince = nil
            session.setHidden(false, because: .targetMissing)
        }
        let previous = session.planned.resolved.shape
        guard moved(from: previous, to: resolved.shape) else { return }
        try? session.move(to: next)
    }

    func targetMissing(_ session: PointSession) {
        let since = goneSince ?? Date()
        goneSince = since
        session.setHidden(true, because: .targetMissing)
        if session.config.duration > 0, Date().timeIntervalSince(since) >= Self.goneLimit {
            session.finish(.targetGone)
        }
    }

    func moved(from old: TargetShape, to new: TargetShape) -> Bool {
        if old.anchor.distance(to: new.anchor) > Self.moveThreshold { return true }
        return old.rect?.size != new.rect?.size
    }
}
