# macOS overlay APIs, targeting, distribution and prior art - verified facts

Research date: 2026-10-08. Every fact below was read on the page linked next to it (Apple reference pages were read through Apple's JSON mirror of the same page). Items not confirmed on an opened page are marked UNVERIFIED.

## 1. Click-through, always-on-top, transparent overlay window

**Click-through**
- `NSWindow.ignoresMouseEvents`: "A Boolean value that indicates whether the window is transparent to mouse events." https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents

**Window level**
- `NSWindow.Level` is ordered lowest to highest: normal, floating, submenu/tornOffMenu, modalPanel, dock, mainMenu, statusBar, popUpMenu, screenSaver. https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct
- `.screenSaver` https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/screensaver - `.statusBar` https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/statusbar - `.popUpMenu` https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/popupmenu
- Apple DTS (May 2026): "`.screenSaver` (level 1000) is required, since `.floating` (3) and `.statusBar` (25) both sit below full-screen content." https://developer.apple.com/forums/thread/826308
- `CGShieldingWindowLevel()` is for captured displays; Apple: "this technique is not recommended." Do not use. https://developer.apple.com/documentation/coregraphics/cgshieldingwindowlevel()
- Raw CG level keys are "not recommended for use in applications". https://developer.apple.com/documentation/coregraphics/cgwindowlevelforkey(_:)

**Collection behavior**
- Overview: "primary, auxiliary, and canJoinAllApplications only apply to full screen and Stage Manager. They're also mutually exclusive." https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct
- `.canJoinAllSpaces` "The window can appear in all spaces." https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces
- `.stationary` "Mission Control doesn't affect the window." https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/stationary
- `.fullScreenAuxiliary` "The window displays on the same space as the full screen window." https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary
- `.ignoresCycle` https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/ignorescycle
- `.transient` is "the default behavior if windowLevel isn't equal to normal", so a screenSaver-level window hides in Mission Control unless canJoinAllSpaces/stationary are set explicitly. https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/transient
- `.canJoinAllApplications` (macOS 13+): "Use this collection behavior for floating windows and system overlays." https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications

**Transparency**
- `backgroundColor` https://developer.apple.com/documentation/appkit/nswindow/backgroundcolor - `isOpaque` https://developer.apple.com/documentation/appkit/nswindow/isopaque - `hasShadow` https://developer.apple.com/documentation/appkit/nswindow/hasshadow - `alphaValue` https://developer.apple.com/documentation/appkit/nswindow/alphavalue
- `.borderless` windows "can't become key or main, unless the value of canBecomeKey or canBecomeMain is true." https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/borderless

**Not stealing focus, no Dock icon**
- `.nonactivatingPanel` "does not activate the owning app." https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
- `NSPanel` https://developer.apple.com/documentation/appkit/nspanel - panels hide on deactivate by default, so set `hidesOnDeactivate = false`. https://developer.apple.com/documentation/appkit/nspanel/isfloatingpanel
- `NSApplication.ActivationPolicy`: `.accessory` "doesn't appear in the Dock and doesn't have a menu bar"; `.prohibited` "may not create windows or be activated. This is also the default for unbundled executables that don't have Info.plist files." https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/accessory - https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/prohibited
  A SwiftPM CLI starts as `.prohibited` and MUST call `NSApplication.shared.setActivationPolicy(.accessory)` before showing the overlay. https://developer.apple.com/documentation/appkit/nsapplication/setactivationpolicy(_:)
- `orderFrontRegardless()` "Moves the window to the front of its level, even if its application isn't active." https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless()

**Apple DTS recipe for an overlay above other apps' full-screen Spaces (May 2026)** https://developer.apple.com/forums/thread/826308
- DTS: "1. Accessory activation policy ... `NSApp.setActivationPolicy(.accessory)`." "2. NSPanel with .nonactivatingPanel. An NSWindow activates its app when ordered front, which can cause a full-screen app to exit its Space. An NSPanel with the .nonactivatingPanel style mask doesn't."
- DTS sample: `NSPanel(styleMask: [.nonactivatingPanel, ...])`, `isFloatingPanel = true`, `hidesOnDeactivate = false`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary]`, `orderFrontRegardless()`. The original poster confirmed it "stayed on top in all tested scenarios".

**Permission to merely draw**: none of the pages above lists any TCC requirement. No Screen Recording, no Accessibility for drawing. Confirmed empirically by the probe in `docs/spikes/` (window at layer 1000 without any prompt). Permissions enter only for target lookup (section 3).

**All displays**: `NSScreen.screens` "should not be cached." https://developer.apple.com/documentation/appkit/nsscreen/screens - `screensHaveSeparateSpaces` https://developer.apple.com/documentation/appkit/nsscreen/screenshaveseparatespaces - window server limits "position coordinates to ±16,000 and sizes to 10,000". https://developer.apple.com/documentation/appkit/nswindow/setframe(_:display:)

**Known caveats**
- 2008 Spaces 3D-switch bug: screenSaver-level ignoresMouseEvents overlay stopped ignoring clicks during the switch animation. https://web.archive.org/web/20140116140526id_/http://lists.apple.com/archives/cocoa-dev/2008/Jun/msg02207.html Relevance on macOS 26 UNVERIFIED.
- canJoinAllSpaces + fullScreenAuxiliary puts the panel on every Space at once. https://developer.apple.com/forums/thread/783576
- Without `.accessory` / non-activating panel: "when other APP enter full screen, the overlay disappears". https://developer.apple.com/forums/thread/759780
- macOS 26.3 RC regression (Feb 2026): "mouse events are intercepted by the entire transparent window rather than only the opaque regions" (FB21879511), Apple: "fixed in the public release of macOS 26.3"; one unconfirmed report it returned in 26.4 beta. Keep `ignoresMouseEvents = true` as the primary mechanism and test every 26.x point release. https://developer.apple.com/forums/thread/814798

## 2. Coordinate systems

- AppKit origin is the bottom-left of the menu-bar screen. https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaDrawingGuide/Transforms/Transforms.html
- `NSScreen.frame` includes menu bar and dock https://developer.apple.com/documentation/appkit/nsscreen/frame - `visibleFrame` excludes them https://developer.apple.com/documentation/appkit/nsscreen/visibleframe
- `NSScreen.screens[0]` "is the screen that contains the menu bar and whose origin is at the point (0, 0) ... may not be the same as the one returned by the main method". https://developer.apple.com/documentation/appkit/nsscreen/screens - `NSScreen.main` is the screen with the key window. https://developer.apple.com/documentation/appkit/nsscreen/main
- Top-left systems: `CGDisplayBounds` https://developer.apple.com/documentation/coregraphics/cgdisplaybounds(_:) - `kCGWindowBounds` https://developer.apple.com/documentation/coregraphics/kcgwindowbounds - `kAXPositionAttribute` "0,0 represent the top-left corner of the screen that displays the menu bar" https://developer.apple.com/documentation/applicationservices/kaxpositionattribute - `CGMainDisplayID()` https://developer.apple.com/documentation/coregraphics/cgmaindisplayid()
- Apple's own flip formula: "`p.y = main_display_height - p.y; /* not p.y = (main_display_height - 1) - p.y */`" https://developer.apple.com/documentation/coregraphics/cgevent/unflippedlocation
- Conversion (H = `NSScreen.screens[0].frame.height`, never `NSScreen.main`): point `appkitY = H - cgY`; rect `appkitRect.origin.y = H - cgRect.origin.y - cgRect.height`; x and sizes unchanged.
- Retina: all geometry APIs above are in points; only pixel buffers and screenshots need `backingScaleFactor`. https://developer.apple.com/documentation/appkit/nsscreen/backingscalefactor

## 3. Finding a target

**(a) Window by app/title to rect**
- `CGWindowListCopyWindowInfo` https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:) - keys `kCGWindowBounds` https://developer.apple.com/documentation/coregraphics/kcgwindowbounds, `kCGWindowOwnerName` https://developer.apple.com/documentation/coregraphics/kcgwindowownername, `kCGWindowName` "(few applications set the Quartz window name)" https://developer.apple.com/documentation/coregraphics/kcgwindowname, `kCGWindowOwnerPID` https://developer.apple.com/documentation/coregraphics/kcgwindowownerpid, `kCGWindowLayer` https://developer.apple.com/documentation/coregraphics/kcgwindowlayer, `kCGWindowIsOnscreen` https://developer.apple.com/documentation/coregraphics/kcgwindowisonscreen
- Gotcha 1: `kCGWindowName` needs Screen Recording (Quinn, DTS, Dec 2019). https://developer.apple.com/forums/thread/126860
- Gotcha 2 (macOS 26 Tahoe, Jul 2026): without Screen Recording, `kCGWindowOwnerName` for other apps' windows is nil; "which keys are populated without permission is undocumented and may change at any time". https://developer.apple.com/forums/thread/839069 - `CGPreflightScreenCaptureAccess()` https://developer.apple.com/documentation/coregraphics/cgpreflightscreencaptureaccess()
- Permission-free route: `NSWorkspace.shared.runningApplications` https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications (`localizedName`, `bundleIdentifier`, `processIdentifier`) matched against `kCGWindowOwnerPID` + `kCGWindowBounds`.

**(b) UI element by role/label to rect (Accessibility)**
- `AXUIElementCreateApplication(pid)` https://developer.apple.com/documentation/applicationservices/1459374-axuielementcreateapplication - `AXUIElementCopyAttributeValue` https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue - `kAXChildrenAttribute` https://developer.apple.com/documentation/applicationservices/kaxchildrenattribute - `kAXRoleAttribute` https://developer.apple.com/documentation/applicationservices/kaxroleattribute - `kAXTitleAttribute` https://developer.apple.com/documentation/applicationservices/kaxtitleattribute - `kAXDescriptionAttribute` https://developer.apple.com/documentation/applicationservices/kaxdescriptionattribute
- Geometry: `kAXPositionAttribute` + `kAXSizeAttribute` https://developer.apple.com/documentation/applicationservices/kaxsizeattribute decoded with `AXValueGetValue` https://developer.apple.com/documentation/applicationservices/1462933-axvaluegetvalue
- Hit test: `AXUIElementCopyElementAtPosition` "in top-left relative screen coordinates". https://developer.apple.com/documentation/applicationservices/1462077-axuielementcopyelementatposition
- Permission: `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt` ("Prompting occurs asynchronously and does not affect the return value"). https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions

**TCC gotcha: the grant goes to the responsible process, not the CLI**
- Quinn (Apple DTS): "The user's decision to be recorded for the whole app, not that specific helper tool"; ad-hoc signed code causes "excessive prompts". https://developer.apple.com/forums/thread/678819 - https://developer.apple.com/forums/thread/741622
- Attribution chain explained: "the request actually made is for Calendar access by Terminal.app, on behalf of the tool ls." https://eclecticlight.co/2018/10/02/how-privacy-protection-is-enforced-through-the-attribution-chain/
- OpenClaw's own permissions doc: "macOS TCC grants Accessibility to the code identity of the process it sees." "Ad-hoc signatures generate a new identity every build." https://docs.openclaw.ai/platforms/mac/permissions
- Consequence: when launched by Claude Code inside Terminal, iTerm or VS Code, the Accessibility row to enable is the terminal or IDE. `bigarrow doctor` must name that app.

**(c) Mouse position**
- `NSEvent.mouseLocation` (AppKit bottom-left) https://developer.apple.com/documentation/appkit/nsevent/mouselocation - `CGEvent(source: nil)?.location` (top-left) https://developer.apple.com/documentation/coregraphics/cgevent/location. No permission documented.

## 4. Rendering good-looking arrows

- `CAShapeLayer` is antialiased and resolution independent. https://developer.apple.com/documentation/quartzcore/cashapelayer - `strokeEnd` (animatable, 0 to 1) https://developer.apple.com/documentation/quartzcore/cashapelayer/strokeend - draw-on = `CABasicAnimation(keyPath: "strokeEnd")` https://developer.apple.com/documentation/quartzcore/cabasicanimation
- `CASpringAnimation` https://developer.apple.com/documentation/quartzcore/caspringanimation - `init(perceptualDuration:bounce:)` macOS 14+ https://developer.apple.com/documentation/quartzcore/caspringanimation/init(perceptualduration:bounce:)
- Glow: `shadowColor` https://developer.apple.com/documentation/quartzcore/calayer/shadowcolor - `shadowOpacity` https://developer.apple.com/documentation/quartzcore/calayer/shadowopacity - `shadowRadius` https://developer.apple.com/documentation/quartzcore/calayer/shadowradius
- Layer hosting: `NSView.wantsLayer` https://developer.apple.com/documentation/appkit/nsview/wantslayer
- Arrow geometry: `addQuadCurve` https://developer.apple.com/documentation/coregraphics/cgmutablepath/addquadcurve(to:control:transform:) - `addCurve` https://developer.apple.com/documentation/coregraphics/cgmutablepath/addcurve(to:control1:control2:transform:) - `addLines(between:)` https://developer.apple.com/documentation/coregraphics/cgmutablepath/addlines(between:transform:) - `CGPath.copy(strokingWithWidth:...)` for a single fillable outline with one glow https://developer.apple.com/documentation/coregraphics/cgpath
- Sign font: `NSFont.systemFont(ofSize:weight:)` https://developer.apple.com/documentation/appkit/nsfont/systemfont(ofsize:weight:) + `NSFontDescriptor.SystemDesign.rounded` https://developer.apple.com/documentation/appkit/nsfontdescriptor/systemdesign/rounded via `withDesign(.rounded)` https://developer.apple.com/documentation/appkit/nsfontdescriptor/withdesign(_:) gives SF Pro Rounded with no bundled font.
- Pill: a solid high-contrast `CAShapeLayer` pill with shadow is simpler and more legible than `NSVisualEffectView`. https://developer.apple.com/documentation/appkit/nsvisualeffectview
- SwiftUI alternative: `NSHostingView` https://developer.apple.com/documentation/swiftui/nshostingview + `Canvas` https://developer.apple.com/documentation/swiftui/canvas (not needed; AppKit + Core Animation is smaller and fully controllable).

## 5. Prior art

| Tool | URL | License | CLI | Arrows | AX targeting | Agent-driveable | Last activity |
|---|---|---|---|---|---|---|---|
| ScreenAnnotator (nfunky) | https://github.com/nfunky/macos-screenannotator | MIT | no | yes | no | no | 2026-07 |
| MarkerOn | https://github.com/ifer47/markeron | MIT | no | yes | no | no | 2026-10 (Tauri) |
| ScreenPen | https://github.com/rsusik/screenpen | GPL-3.0 | launch flag only | no | no | no | 2025-01 |
| Presentify | https://presentifyapp.com | proprietary | no | yes | no | Stream Deck only | v8.1.4 |
| ZoomIt for Mac (Microsoft) | https://github.com/microsoft/ZoomitForMac | MIT | no | yes | no | no | 2026-10 |
| Shottr | https://shottr.cc | proprietary | URL scheme | on screenshots | no | partial | 2026-09 |
| Annotate (adammcarter) | https://github.com/adammcarter/annotate | MIT | no (MCP only) | yes (`annotate_arrow`) | partial (`annotate_locate`) | yes (MCP) | 2026-07, 1 commit |
| MacosUseSDK (mediar-ai) | https://github.com/mediar-ai/MacosUseSDK | MIT | yes | no (boxes on all AX elements) | yes | yes | 2026-04 |
| Loupe | https://github.com/smughead/Loupe | MIT | no | no | yes (inspector) | no | 2026-09 |
| Hinto | https://github.com/yhao3/hinto | MIT | no | no (hint labels) | yes | no | 2026-01 |
| DrawPen | https://github.com/DmytroVasin/DrawPen | MIT | no | yes | no | no | 2026-09 (Electron) |
| openclaudia task-banner | https://claudeskills.info/skills/openclaudia/openclaudia-skills/task-banner/ | MIT | yes (JXA) | no (text banner) | no | yes | auto-dismiss 4 s, zero permissions |
| Anthropic computer-use demo | https://github.com/anthropics/anthropic-quickstarts/tree/main/computer-use-demo | MIT | no | no | no | is the agent | no click visualizer |
| Agent-S | https://github.com/simular-ai/Agent-S | Apache-2.0 | yes | no | no | is the agent | 2026-09 |
| UI-TARS-desktop | https://github.com/bytedance/UI-TARS-desktop | Apache-2.0 | yes | no | no | is the agent | 2026-10 |
| self-operating-computer | https://github.com/OthersideAI/self-operating-computer | MIT | yes | no | no | is the agent | 2025-09 |
| Peekaboo | https://github.com/openclaw/Peekaboo and https://github.com/openclaw/Peekaboo/blob/main/docs/visualizer.md | MIT | yes (+MCP) | no pointer arrows; ghost cursor, click rings, typing pills, element outlines (fade 2 s); doc: "No labels... there is no 'Click' text" | yes | narrates the agent's own actions, no "point here" command | 2026-10, v4.9.0 |
| Fluegel | https://github.com/steipete/Fluegel | MIT | yes | no | no | TCC permission proxy | 2026-09 |
| cua (trycua) | https://github.com/trycua/cua | MIT | yes | no (Set-of-Mark on screenshots) | no | is the agent | 2026-10 |
| macOS-use (browser-use) | https://github.com/browser-use/macOS-use | MIT | scripts | no | UNVERIFIED | is the agent | archived 2026-09 |

**Explicit answer: no existing tool does it.** Nothing found is a macOS CLI that draws a big arrow plus a text label pointing at a coordinate, window or Accessibility element as a click-through overlay that auto-dismisses. Closest partials: Annotate (arrow + AX locate, but MCP-only, 1 commit), MacosUseSDK (CLI + AX + timed dismiss, but only boxes around everything), Peekaboo (polished overlays, but explicitly no labels or pointer arrows), task-banner (zero-permission auto-dismissing text banner). The gap is real.

## 6. Distribution and skill registration

**Unbundled CLI showing AppKit windows**
- Works from a `main.swift` SwiftPM executable: `NSApplication.shared` + `run()`. https://theswiftdev.com/how-to-build-macos-apps-using-only-the-swift-package-manager/ - https://developer.apple.com/documentation/appkit/nsapplication/shared - https://developer.apple.com/documentation/appkit/nsapplication/run()
- Must switch from `.prohibited` to `.accessory` (section 1).
- Embedding an Info.plist into a SwiftPM executable: `linkerSettings: [.unsafeFlags(["-Xlinker","-sectcreate","-Xlinker","__TEXT","-Xlinker","__info_plist","-Xlinker","Resources/Info.plist"])]`. https://forums.swift.org/t/swift-package-manager-use-of-info-plist-use-for-apps/6532

**Homebrew**
- Taps: https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap - Formula Cookbook https://docs.brew.sh/Formula-Cookbook - open-source CLI software belongs in a formula built from source, not a cask https://docs.brew.sh/Acceptable-Casks
- Swift-package formula templates: xcbeautify https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/x/xcbeautify.rb, mas (`depends_on xcode: ["26.0", :build]`, `uses_from_macos "swift" => :build`) https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/m/mas.rb. Template: `system "swift", "build", *std_swift_args` + `bin.install ".build/release/<name>"`.
- Gatekeeper: source-built formula binaries are never quarantined. Quinn: "Gatekeeper typically only kicks in if the app is quarantined." https://developer.apple.com/forums/thread/740680 - curl does not quarantine https://eclecticlight.co/2025/12/08/who-decides-to-quarantine-files/
- Casks: Homebrew 5.0.0 deprecates `--no-quarantine` and unsigned casks; "We will disable all Homebrew/homebrew-cask casks that fail Gatekeeper checks in September 2026." https://brew.sh/2025/11/12/homebrew-5.0.0/ - 7.0.0 (2026-09-13) adds attestations for third-party tap bottles https://brew.sh/2026/09/13/homebrew-7.0.0/
- Notarization requires a Developer ID Application certificate; "it's not currently possible to staple tickets to [standalone binaries]". https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution - https://developer.apple.com/documentation/security/customizing-the-notarization-workflow
- Ad-hoc signing: "all code on Apple silicon must be at least ad hoc signed", the linker does it automatically. https://developer.apple.com/forums/thread/740680 - https://keith.github.io/xcode-man-pages/codesign.1.html
- Toolchain: Swift 6.4 released 2026-09-15 https://swift.org/blog/swift-6.4-released/ - this Mac has Swift 6.3.1 (`swift --version`, 2026-10-08).

**Claude Code skills** (canonical https://code.claude.com/docs/en/skills)
- Follows the Agent Skills open standard https://agentskills.io/specification (`name` max 64 chars, lowercase letters, numbers, hyphens, must match the directory; `description` max 1024 chars).
- Locations: personal `~/.claude/skills/<name>/SKILL.md`, project `.claude/skills/<name>/SKILL.md`, plugin `<plugin>/skills/<name>/SKILL.md`.
- Frontmatter: `name`, `description` (truncated at 1,536 characters in the listing), `when_to_use`, `argument-hint`, `disable-model-invocation`, `user-invocable`, `allowed-tools` (e.g. `allowed-tools: Bash(bigarrow *) Bash(say *)`), `model`, `effort`, `context: fork`, `license`, `compatibility`. "Keep SKILL.md under 500 lines."
- Distribution as plugin: `.claude-plugin/plugin.json` + `skills/` https://code.claude.com/docs/en/plugins/overview - marketplace https://code.claude.com/docs/en/plugin-marketplaces

**OpenClaw skills** (official https://docs.openclaw.ai/skills)
- "Skills are markdown instruction files (SKILL.md) that teach the agent how and when to use tools." Locations: `<workspace>/skills`, `~/.openclaw/skills`, bundled.
- Frontmatter: required `name`, `description`; optional `homepage`, `user-invocable`, `disable-model-invocation`; `metadata.openclaw.requires.bins` ("Every listed binary must be on PATH"), `os: darwin`, `install` with kind `brew` and a `formula`. "OpenClaw does not auto-install Homebrew."
- Install: `openclaw skills install @owner/<slug>` https://docs.openclaw.ai/cli/skills - ClawHub publishing `clawhub skill publish ./my-skill --dry-run` https://docs.openclaw.ai/tools/clawhub - skill format https://docs.openclaw.ai/clawhub/skill-format

## 7. Text-to-speech synergy

- `say [-v voice] [-r rate] [-o outfile] [-f file | string ...]`, voices with `say -v '?'`. https://keith.github.io/xcode-man-pages/say.1.html
- Spawn `/usr/bin/say "<sign text>"` concurrently with the overlay; kill it on dismiss.

## Design conclusions that fall out of the evidence

1. Architecture: SwiftPM executable, `setActivationPolicy(.accessory)`, borderless non-activating `NSPanel`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `ignoresMouseEvents = true`, clear background, no shadow, `hidesOnDeactivate = false`, `orderFrontRegardless()`. Zero permissions for the drawing path.
2. Targeting tiers: `--at x,y` and `--mouse` (no permission), `--window "App"` via running-application pid + `kCGWindowBounds` (no permission; do not rely on owner or window names on Tahoe), `--element` via Accessibility (permission on the responsible terminal or IDE; prompt with `kAXTrustedCheckOptionPrompt`).
3. Distribution: source-built formula in Franz's existing tap, no notarization needed, the linker ad-hoc signs on arm64; no cask. Claude Code skill with `allowed-tools: Bash(bigarrow *) Bash(say *)`; OpenClaw skill with `requires.bins` and a `brew` installer entry.
4. Test matrix: full-screen app Space, Stage Manager, "Displays have separate Spaces" on and off, every macOS 26.x point release (26.3 RC click-through regression).
