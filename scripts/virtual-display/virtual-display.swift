// virtual-display: create a temporary CGVirtualDisplay for multi-display tests.
// Session-only: nothing is written to the persistent display configuration, and the
// display disappears when the CGVirtualDisplay object is released or the process exits.
import CoreGraphics
import Foundation

struct Options {
    var width = 1920
    var height = 1080
    var scale = 1
    var seconds = 10.0
    var origin: CGPoint?
}

let usage = "usage: virtual-display --width W --height H --hidpi 0|1 --seconds N [--origin x,y]"
let pollInterval: useconds_t = 50_000
let activationTimeout = 5.0

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("virtual-display: \(message)\n".utf8))
    exit(1)
}

func log(_ message: String) {
    FileHandle.standardError.write(Data("virtual-display: \(message)\n".utf8))
}

func parsePositive(_ text: String, _ flag: String) -> Int {
    guard let value = Int(text), value > 0 else { fail("\(flag) needs a positive integer, got '\(text)'") }
    return value
}

func parseOrigin(_ text: String) -> CGPoint {
    let parts = text.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard parts.count == 2, let x = parts[0], let y = parts[1] else { fail("--origin needs x,y, got '\(text)'") }
    return CGPoint(x: x, y: y)
}

func parseOptions(_ args: [String]) -> Options {
    var options = Options()
    var index = 0
    while index < args.count {
        let flag = args[index]
        guard index + 1 < args.count else { fail("\(flag) needs a value\n\(usage)") }
        let value = args[index + 1]
        switch flag {
        case "--width": options.width = parsePositive(value, flag)
        case "--height": options.height = parsePositive(value, flag)
        case "--hidpi":
            guard value == "0" || value == "1" else { fail("--hidpi must be 0 or 1") }
            options.scale = value == "1" ? 2 : 1
        case "--seconds":
            guard let seconds = Double(value), seconds > 0 else { fail("--seconds needs a positive number") }
            options.seconds = seconds
        case "--origin": options.origin = parseOrigin(value)
        default: fail("unknown argument '\(flag)'\n\(usage)")
        }
        index += 2
    }
    return options
}

/// Width and height are logical points; with HiDPI the backing mode has twice the pixels.
func makeDisplay(_ options: Options) -> CGVirtualDisplay {
    let pixelsWide = options.width * options.scale
    let pixelsHigh = options.height * options.scale
    let descriptor = CGVirtualDisplayDescriptor()
    descriptor.setDispatchQueue(DispatchQueue.main)
    descriptor.name = "bigarrow test display"
    descriptor.maxPixelsWide = UInt32(pixelsWide)
    descriptor.maxPixelsHigh = UInt32(pixelsHigh)
    descriptor.sizeInMillimeters = CGSize(width: Double(options.width) * 0.2646, height: Double(options.height) * 0.2646)
    descriptor.vendorID = 0xB16A
    descriptor.productID = 0x0001
    descriptor.serialNum = UInt32(getpid())
    descriptor.terminationHandler = { _, _ in log("window server terminated the virtual display") }
    guard let display = CGVirtualDisplay(descriptor: descriptor) else { fail("CGVirtualDisplay init returned nil") }
    let settings = CGVirtualDisplaySettings()
    settings.hiDPI = options.scale == 2 ? 1 : 0
    settings.modes = [CGVirtualDisplayMode(width: UInt(pixelsWide), height: UInt(pixelsHigh), refreshRate: 60)]
    guard display.apply(settings) else { fail("applySettings failed") }
    return display
}

/// Online includes hardware-mirrored displays, which the active list hides behind their master.
func onlineDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success else { fail("CGGetOnlineDisplayList failed") }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { fail("CGGetOnlineDisplayList failed") }
    return Array(ids.prefix(Int(count)))
}

func describeDisplays() -> String {
    onlineDisplays().map { id in
        let bounds = CGDisplayBounds(id)
        let main = CGDisplayIsMain(id) != 0 ? " main" : ""
        return "\(id)@\(Int(bounds.minX)),\(Int(bounds.minY)) \(Int(bounds.width))x\(Int(bounds.height))\(main) mirrors=\(CGDisplayMirrorsDisplay(id))"
    }.joined(separator: "; ")
}

func waitUntil(_ what: String, _ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(activationTimeout)
    while !condition() {
        guard Date() < deadline else { fail("timed out after \(activationTimeout)s waiting for \(what)") }
        RunLoop.main.run(until: Date().addingTimeInterval(Double(pollInterval) / 1_000_000))
    }
}

/// The mode whose logical size is width x height and whose backing store has the requested scale.
func wantedMode(_ id: CGDirectDisplayID, _ options: Options) -> CGDisplayMode {
    let query = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
    let modes = (CGDisplayCopyAllDisplayModes(id, query) as? [CGDisplayMode]) ?? []
    let match = modes.first { mode in
        mode.width == options.width && mode.height == options.height && mode.pixelWidth == options.width * options.scale
    }
    guard let match else {
        let found = modes.map { "\($0.width)x\($0.height)@\($0.pixelWidth)px" }.joined(separator: ", ")
        fail("no \(options.width)x\(options.height) mode at scale \(options.scale); modes: [\(found)]")
    }
    return match
}

/// One session-only transaction (kCGConfigureForSession), never kCGConfigurePermanently.
/// macOS may bring a new display up as a mirror and as the main display, so the transaction
/// breaks every mirror involving it, keeps the previous main display at (0,0) (which keeps it main)
/// and places the virtual display at --origin, or to the right of the main display by default.
func configure(_ id: CGDirectDisplayID, _ previousMain: CGDirectDisplayID, _ options: Options) {
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success, let config else { fail("CGBeginDisplayConfiguration failed") }
    let origin = options.origin ?? CGPoint(x: CGDisplayBounds(previousMain).width, y: 0)
    var results = [CGConfigureDisplayWithDisplayMode(config, id, wantedMode(id, options), nil)]
    for other in onlineDisplays() where other == id || CGDisplayMirrorsDisplay(other) == id {
        results.append(CGConfigureDisplayMirrorOfDisplay(config, other, kCGNullDirectDisplay))
    }
    results.append(CGConfigureDisplayOrigin(config, previousMain, 0, 0))
    results.append(CGConfigureDisplayOrigin(config, id, Int32(origin.x), Int32(origin.y)))
    if let failure = results.first(where: { $0 != .success }) {
        CGCancelDisplayConfiguration(config)
        fail("configuring display \(id) failed: CGError \(failure.rawValue)")
    }
    let completion = CGCompleteDisplayConfiguration(config, .forSession)
    guard completion == .success else { fail("CGCompleteDisplayConfiguration failed: CGError \(completion.rawValue)") }
}

func frameJSON(_ id: CGDirectDisplayID) -> String {
    let bounds = CGDisplayBounds(id)
    let frame = "{\"x\":\(Int(bounds.minX)),\"y\":\(Int(bounds.minY)),\"width\":\(Int(bounds.width)),\"height\":\(Int(bounds.height))}"
    return "{\"displayID\":\(id),\"frame\":\(frame)}"
}

func isSettled(_ id: CGDirectDisplayID, _ previousMain: CGDirectDisplayID, _ options: Options) -> Bool {
    let bounds = CGDisplayBounds(id)
    return Int(bounds.width) == options.width && Int(bounds.height) == options.height
        && CGDisplayIsInMirrorSet(id) == 0 && CGMainDisplayID() == previousMain
}

func activate(_ id: CGDirectDisplayID, _ previousMain: CGDirectDisplayID, _ options: Options) {
    waitUntil("display \(id) to come online") { onlineDisplays().contains(id) && CGDisplayIsActive(id) != 0 }
    log("online: \(describeDisplays())")
    configure(id, previousMain, options)
    waitUntil("display \(id) to be extended at \(options.width)x\(options.height) with \(previousMain) main") {
        isSettled(id, previousMain, options)
    }
    log("configured: \(describeDisplays())")
    print(frameJSON(id))
    fflush(stdout)
}

var liveDisplay: CGVirtualDisplay?
var signalSources: [DispatchSourceSignal] = []

/// Exiting closes this process's window-server connection, which removes the virtual display.
/// Tested on macOS 26.1: the display is gone right after exit. Releasing the object inside a
/// still-running process did not remove it within 5 s, so exit is the teardown we rely on.
@MainActor
func shutdown(_ reason: String) {
    guard let id = liveDisplay?.displayID else { exit(0) }
    liveDisplay = nil
    log("releasing display \(id) and exiting (\(reason))")
    exit(0)
}

@MainActor
func installSignalHandlers() {
    for sig in [SIGINT, SIGTERM, SIGHUP] {
        signal(sig, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { shutdown("signal \(sig)") } }
        source.resume()
        signalSources.append(source)
    }
}

let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
let previousMain = CGMainDisplayID()
installSignalHandlers()
// The pool keeps autoreleased references made during setup from outliving the release in shutdown.
autoreleasepool {
    liveDisplay = makeDisplay(options)
    guard let createdID = liveDisplay?.displayID else { fail("virtual display vanished before activation") }
    activate(createdID, previousMain, options)
}
DispatchQueue.main.asyncAfter(deadline: .now() + options.seconds) {
    MainActor.assumeIsolated { shutdown("\(options.seconds)s elapsed") }
}
dispatchMain()
