import AppKit
import BigArrowCore
import BigArrowOverlay
import Foundation

/// How a card ends by itself, as every arrow does: its time limit, `bigarrow stop` (a signal),
/// the agent session exiting. SIGUSR1 means `card --update` left a new card to show.
extension CardSession {
    static let endSignals = [SIGTERM, SIGINT, SIGHUP]

    func installLifetime() {
        for number in Self.endSignals {
            listen(number) { [weak self] in self?.finish(.stopped, value: nil) }
        }
        listen(SIGUSR1) { [weak self] in self?.applyUpdate() }
        let duration = document.resolvedDuration
        if duration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                MainActor.assumeIsolated { self?.finish(.timeout, value: nil) }
            }
        }
        watchOwner()
        if document.say == true { speech = Speech.say(document.title, voice: nil) }
    }

    func listen(_ number: Int32, handler: @escaping @MainActor () -> Void) {
        signal(number, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { handler() } }
        source.resume()
        signalSources.append(source)
    }

    func watchOwner() {
        guard let pid = owner.pid else { return }
        guard PidRegistry.isProcessAlive(pid) else {
            DispatchQueue.main.async { MainActor.assumeIsolated { self.finish(.ownerGone, value: nil) } }
            return
        }
        ownerWatch = OwnerWatch(pid: pid) { [weak self] in self?.finish(.ownerGone, value: nil) }
    }

    /// The pid file is the "card is on screen" signal for the detaching parent.
    func announceWhenShown() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                do {
                    try self.writeRecord()
                } catch {
                    Output.fail(.badInput("cannot write the pid file: \(error.localizedDescription)"), json: true)
                }
            }
        }
    }

    func writeRecord() throws {
        guard let frame = controller?.frame else { return }
        let screens = ScreenReader.current()
        let display = (try? screens.display(containing: CGPoint(x: frame.midX, y: frame.midY)))?.index ?? 0
        let target = arrows.shown?.resolved.shape.anchor ?? CGPoint(x: frame.midX, y: frame.midY)
        var record = ArrowRecord(
            pid: getpid(), text: document.title, target: target, display: display + 1,
            sign: (frame, "card"), startedAt: startedAt
        )
        record.owner = owner.pid == nil && owner.session == nil ? nil : owner
        record.kind = "card"
        record.controls = controller?.view.controls().map { control in
            CardControl(name: control.name, rect: CGRect(
                x: frame.minX + control.rect[0], y: frame.minY + control.rect[1], width: control.rect[2], height: control.rect[3]
            ))
        }
        try PidRegistry().write(record)
    }

    /// Shows the card `card --update` left in the registry at the same place. What the human
    /// copied, ticked or typed so far stays in the reply.
    func applyUpdate() {
        let file = CardUpdate.file(for: getpid())
        defer { try? FileManager.default.removeItem(at: file) }
        guard let data = try? Data(contentsOf: file), let next = try? CardDocument.parse(data),
              let topLeft = controller?.frame?.origin, let display = try? placementDisplay() else { return }
        let previous = document
        document = next
        guard let view = try? makeView(display: display) else {
            document = previous
            return
        }
        controller?.close()
        let controller = CardController(view: view)
        controller.show(at: topLeft, theme: next.theme)
        self.controller = controller
        view.markActive(arrows.retarget(next))
    }

    func finish(_ outcome: CardOutcome, value: String?) {
        guard !finished else { return }
        finished = true
        speech?.terminate()
        ownerWatch?.stop()
        controller?.close()
        arrows.dismiss {
            let registry = PidRegistry()
            registry.remove(pid: getpid())
            let reply = self.progress.reply(pid: getpid(), result: outcome, value: value, startedAt: self.startedAt)
            switch self.replyTarget {
            case .stdout: Output.print(reply.line())
            case .file: try? registry.writeReply(reply)
            }
            exit(reply.exitCode)
        }
    }
}

/// Where `card --update` leaves the new card for a running one.
enum CardUpdate {
    static func file(for pid: Int32) -> URL {
        PidRegistry().directory.appendingPathComponent("\(pid).update")
    }
}

/// Speaks a sentence with macOS `say`, for when the human is not looking.
enum Speech {
    static func say(_ text: String, voice: String?) -> Process? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = (voice.map { ["-v", $0] } ?? []) + [text]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return process
        } catch {
            Output.printError("bigarrow: could not run /usr/bin/say: \(error.localizedDescription)")
            return nil
        }
    }
}
