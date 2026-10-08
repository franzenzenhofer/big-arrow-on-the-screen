// Throwaway feasibility probe: click-through, always-on-top arrow + sign overlay from a plain CLI process.
import AppKit
import QuartzCore

final class ArrowView: NSView {
    let target: CGPoint
    let text: String
    init(frame: NSRect, target: CGPoint, text: String) {
        self.target = target; self.text = text
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let ctx = NSGraphicsContext.current!.cgContext
        let tail = CGPoint(x: target.x - 260, y: target.y + 220)
        let ctrl = CGPoint(x: target.x - 240, y: target.y + 40)
        let path = CGMutablePath()
        path.move(to: tail)
        path.addQuadCurve(to: CGPoint(x: target.x - 22, y: target.y + 18), control: ctrl)
        ctx.setShadow(offset: .zero, blur: 18, color: NSColor(red: 1, green: 0.2, blue: 0.1, alpha: 0.8).cgColor)
        ctx.setStrokeColor(NSColor(red: 1, green: 0.27, blue: 0.13, alpha: 1).cgColor)
        ctx.setLineWidth(16); ctx.setLineCap(.round)
        ctx.addPath(path); ctx.strokePath()
        // arrow head
        let head = CGMutablePath()
        head.move(to: target)
        head.addLine(to: CGPoint(x: target.x - 70, y: target.y + 10))
        head.addLine(to: CGPoint(x: target.x - 30, y: target.y + 62))
        head.closeSubpath()
        ctx.setFillColor(NSColor(red: 1, green: 0.27, blue: 0.13, alpha: 1).cgColor)
        ctx.addPath(head); ctx.fillPath()
        // sign
        let font = NSFont.systemFont(ofSize: 44, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        let pill = CGRect(x: tail.x - size.width - 40, y: tail.y - 20, width: size.width + 48, height: size.height + 32)
        let pillPath = CGPath(roundedRect: pill, cornerWidth: 28, cornerHeight: 28, transform: nil)
        ctx.addPath(pillPath); ctx.fillPath()
        str.draw(at: CGPoint(x: pill.minX + 24, y: pill.minY + 16))
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, no focus steal
let screen = NSScreen.main!
let win = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
win.isOpaque = false
win.backgroundColor = .clear
win.hasShadow = false
win.ignoresMouseEvents = true          // click-through
win.level = .screenSaver               // above everything incl. menu bar
win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
// Target given in top-left CG coordinates (what AX / Peekaboo report); convert to AppKit bottom-left.
let cgX = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1])! : 760
let cgY = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 500
let appKitY = screen.frame.height - cgY
let view = ArrowView(frame: screen.frame, target: CGPoint(x: cgX, y: appKitY), text: "Franz, click HERE")
win.contentView = view
win.orderFrontRegardless()
DispatchQueue.main.asyncAfter(deadline: .now() + 6) { app.terminate(nil) }
app.run()
