# big-arrow-on-the-screen - Plan

Written 2026-10-08 by Claude Fable 5.1 for Franz Enzenhofer. Status: plan approved for ticketing, no implementation started. License MIT. Repo: https://github.com/franzenzenhofer/big-arrow-on-the-screen

## 1. Golden goal

An AI agent working on this Mac can put a big, good-looking arrow with a sign on the screen that points at something and says what to do: "Franz, click HERE". One shell command, no focus steal, click-through, gone again by itself. Any agent that can run a shell command gets this through a skill (Claude Code first, OpenClaw second).

Not a drawing app for humans. Not a screenshot annotator. A pointer for an AI that needs the human's hand.

## 2. Status quo (verified 2026-10-08)

- Nothing like it exists. Twenty-six tools were checked (annotators, agent frameworks, Peekaboo, Nameplate, MacosUseSDK, Annotate MCP). None is a macOS CLI that draws an arrow plus label at a target as a click-through overlay and dismisses itself. Table with links: `docs/research/2026-10-08-macos-overlay-apis-and-prior-art.md` section 5.
- Peekaboo (Peter Steinberger, now `openclaw/Peekaboo`, 4.9.0, MIT) has a polished visualizer, but it has no arrow or label primitive, no sticky mode, and draws nothing unless the 23 MB Peekaboo.app is running. Its `see --json` output is useful as a target source. Details: `docs/research/2026-10-08-peekaboo-and-steipete-tools.md`.
- Steinberger's Nameplate (MIT, October 2026) has the right window recipe (click-through non-activating panels on every screen) and a sticky `attention` banner, but no arrow and no coordinate targeting.
- Feasibility is proven, not assumed. An 80-line Swift probe compiled in 3.4 s to a 70 KB binary and drew the arrow and sign above Chrome at window level 1000, no Dock icon, no focus change, no permission prompt, self-exit after 6 s. Source and log: `docs/spikes/2026-10-08-overlay-probe/`.
- This Mac: macOS 26.1, Swift 6.3.1, three displays (built-in 1512x982 at 2x, two 1920x1080 at scale 1 with negative y origins), Peekaboo 3.0.0-beta3 installed, Screen Recording and Accessibility granted to the terminal.

## 3. Is it possible, and how much work

Yes. Drawing the overlay needs no permission at all. Pointing at a coordinate or the mouse needs no permission. Pointing at a window by app name needs no permission when done via the app's pid. Only pointing at a named UI element ("the Save button") needs Accessibility, and that permission belongs to the terminal or IDE that runs the agent, not to the tool.

Effort, estimated from the 30 tickets with S = 0.25, M = 0.75, L = 1.5 agent-days of focused Claude Code work:

| Milestone | Tickets | Agent-days |
|---|---|---|
| M0 Skeleton and proof | 3 | 0.75 |
| M1 MVP: point at a coordinate, skill | 8 | 5.5 |
| M2 Targeting: window, element, mouse, rect | 5 | 4.0 |
| M3 Beauty and behaviour | 7 | 3.75 |
| M4 Distribution | 4 | 2.0 |
| M5 Ecosystem | 3 | 0.75 |
| Total | 30 | 16.75 |

A usable MVP (M0 + M1) is about one working week of agent sessions. Everything through the first Homebrew release (M0 to M4) is about three weeks of agent sessions with review in between. M5 is optional.

## 4. Approaches considered

**A. Build fresh: small Swift CLI plus skill (recommended).** SwiftPM package, AppKit and Core Animation, zero third-party dependencies except swift-argument-parser. The CLI process itself owns the overlay for the duration. Optional adapters read Peekaboo JSON. Pros: tiny binary, 3 s build, no app to install or keep running, no notarization needed for a source-built Homebrew formula, full control over looks. Cons: own Accessibility code for element targeting (a few hundred lines).

**B. Extend Peekaboo upstream with an arrow event.** Pros: large audience, existing overlay plumbing, Steinberger's ecosystem. Cons: requires Peekaboo.app running (no auto-launch), its overlays are not on all Spaces (no `collectionBehavior` set), no sticky mode, 36 MB CLI, Developer ID release pipeline we do not control, upstream review latency, the maintainer joined OpenAI in 2026. Kept as M5 ticket T29: propose upstream after v0.1.0 proves the design.

**C. Skill only, piggyback on Peekaboo's `elementDetection` overlay.** Pros: zero code. Cons: violet box with a 10 pt id chip that fades in 2 s, gated off by default, needs the app. Does not meet "big arrow with a sign". Rejected.

Decision: A, with B as a later proposal and the Peekaboo `see` JSON as an optional input (T15).

## 5. Architecture

```
big-arrow-on-the-screen/
  Package.swift
  Sources/
    BigArrowCore/        pure logic, no AppKit: ScreenSpace, ArrowGeometry, Placement,
                         TargetResolver protocol, Adapters/Peekaboo, result/error types
    BigArrowOverlay/     AppKit + Core Animation: OverlayPanel, ArrowLayer, SignLayer, Animator
    BigArrowTargeting/   WindowTarget (CGWindowList by pid), ElementTarget (Accessibility),
                         MouseTarget, Doctor (permissions, displays)
    bigarrow/            CLI (swift-argument-parser): point, clear, doctor, demo, install-skill
  Tests/
    BigArrowCoreTests/   geometry, placement, coordinate conversion, adapters (fixtures)
    IntegrationTests/    spawns the binary, checks window server + pixels, no mocks
  skill/big-arrow/SKILL.md
  docs/plan, docs/research, docs/spikes, docs/verification, docs/decisions
```

Rules from `~/.claude/CLAUDE.md` apply: files target 200 lines, hard max 450; functions under 30 lines; no mocks; fail fast; named exports; English everywhere.

**Overlay window** (per Apple DTS, https://developer.apple.com/forums/thread/826308): `NSApplication.shared.setActivationPolicy(.accessory)`, then one `NSPanel` per target display with `[.borderless, .nonactivatingPanel]`, `isFloatingPanel = true`, `hidesOnDeactivate = false`, `ignoresMouseEvents = true`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, clear background, no shadow, `orderFrontRegardless()`.

**Coordinates**: input is global top-left logical points (what Accessibility, CGWindowList, Peekaboo and screenshots-in-points report). Flip against `NSScreen.screens[0].frame.height`, never `NSScreen.main`. Rects: `y' = H - y - height`.

**Rendering**: `CAShapeLayer` shaft with `strokeEnd` draw-on, filled arrowhead along the end tangent, glow via layer shadow, sign as a rounded pill with SF Pro Rounded heavy text and a white outline so it reads on light and dark backgrounds. Placement picks the approach direction with the most free space.

**Process model**: the CLI process keeps the overlay alive for `--duration` (default 8 s, 0 = sticky). `--detach` forks and returns the pid. `bigarrow clear` terminates live arrows via pid files in `$TMPDIR/bigarrow/`. Signals fade out and exit 0.

**Targeting tiers and permissions**

| Target | Flag | Mechanism | Permission |
|---|---|---|---|
| Coordinate | `--at X,Y` | flip and draw | none |
| Mouse | `--mouse` | `NSEvent.mouseLocation` | none |
| Rect | `--rect x,y,w,h` | box plus arrow | none |
| Window | `--window App[:title]` | running app pid, `kCGWindowOwnerPID`, `kCGWindowBounds` | none (title match needs Screen Recording) |
| Element | `--element 'Save' --app Safari` | AX tree walk, `kAXPosition/Size` | Accessibility, granted to the terminal or IDE |
| Peekaboo | `--peekaboo B3 --snapshot snap.json` | parse `ui_elements[].bounds` | whatever Peekaboo needed |

**Error contract**: exit 0 ok, 2 bad input, 3 target unresolvable, 4 permission missing. `--json` on every command. One-line errors on stderr naming the fix (for 4: the responsible app to grant).

## 6. CLI surface (v0.1.0)

```
bigarrow point --at 760,500 --text "Franz, click HERE"
bigarrow point --window "Google Chrome" --anchor title --text "This window"
bigarrow point --element "Reload" --app "Google Chrome" --text "Click reload" --say
bigarrow point --mouse --text "You are here" --duration 3
bigarrow point --rect 400,300,200,80 --text "Type your name" --style box
bigarrow point --at 760,500 --text "..." --duration 0 --detach     # sticky, returns pid
bigarrow clear [--all]
bigarrow doctor [--json] [--open-settings] [--request-accessibility]
bigarrow demo
bigarrow install-skill [--claude|--openclaw] [--force]
```

Common options: `--duration S`, `--display N`, `--from auto|top|top-left|...`, `--size S|M|L`, `--style arrow|ring|box`, `--color name|hex`, `--say [--voice V]`, `--follow`, `--until-click`, `--no-animation`, `--json`.

## 7. The skill

`skill/big-arrow/SKILL.md`, Agent Skills standard (https://agentskills.io/specification), frontmatter `name: big-arrow`, `description` with trigger phrases ("show me where", "point to", "which button", "zeig mir wo", "Franz, click here"), `allowed-tools: Bash(bigarrow *) Bash(say *)`, `license: MIT`. Body: decision tree for choosing the target type, how to get coordinates from `tinyscreenshot` (multiply by the downscale factor), from `peekaboo see --json`, or from Claude in Chrome; always a full sentence on the sign; add `--say` when the human is probably not looking; `bigarrow doctor --json` on the first permission error; `bigarrow clear` when the human has acted. The OpenClaw variant is generated from the same body with `metadata.openclaw.requires.bins` and a `brew` installer entry.

## 8. Milestones

- **M0 Skeleton and proof**: T01 repo, T02 CI, T03 spike documented.
- **M1 MVP**: T04 overlay panel, T05 coordinates, T06 arrow geometry, T07 sign, T08 `point --at`, T09 process model and `clear`, T10 skill, T11 integration test.
- **M2 Targeting**: T12 window, T13 element, T14 mouse and rect, T15 Peekaboo adapter, T16 multi-display verification.
- **M3 Beauty and behaviour**: T17 animations, T18 auto placement, T19 styles, T20 `--say`, T21 follow, T22 until-click, T23 doctor.
- **M4 Distribution**: T24 Homebrew formula in `franzenzenhofer/homebrew-tap`, T25 skill installer, T26 README and demo GIF, T27 v0.1.0.
- **M5 Ecosystem**: T28 OpenClaw skill and ClawHub, T29 upstream proposal to Peekaboo and Nameplate, T30 MCP evaluation.

Ticket texts with acceptance criteria: `docs/plan/TICKETS.md` (generated from `docs/plan/tickets.json`, the single source of truth that also created the GitHub issues).

## 9. Risks and how the tickets handle them

- **macOS point releases break click-through** (26.3 RC regression, https://developer.apple.com/forums/thread/814798): T11 integration test plus T16 matrix re-run on every macOS update.
- **Accessibility grant lands on the wrong process** (TCC attribution chain): T23 doctor names the responsible app; T10 skill explains it; T13 exits 4 with instructions.
- **Window names unavailable without Screen Recording on Tahoe**: T12 matches by pid, never by owner name.
- **Looks cheap**: T17 and T18 are first-class tickets, not polish; T26 demo GIF is the acceptance test for "looks good".
- **Scope creep into a Peekaboo clone**: the CLI never clicks, types or captures. Out of scope by design.

## 10. Out of scope for v0.1.0

Clicking or typing for the user, screenshots, Windows or Linux, a GUI, a menu-bar app, notarized casks, MCP server (T30 decides later), multiple simultaneous arrows with choreography.

## 11. Sources read for this plan

All URLs are in the two research files under `docs/research/`. Key ones: Apple DTS overlay recipe https://developer.apple.com/forums/thread/826308, `NSWindow.ignoresMouseEvents` https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents, activation policy for unbundled executables https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/prohibited, coordinate flip https://developer.apple.com/documentation/coregraphics/cgevent/unflippedlocation, TCC responsible process https://developer.apple.com/forums/thread/678819, Tahoe window-name gating https://developer.apple.com/forums/thread/839069, Peekaboo visualizer https://github.com/openclaw/Peekaboo/blob/main/docs/visualizer.md, Nameplate overlay panels https://github.com/steipete/Nameplate/blob/main/Sources/Nameplate/OverlayController.swift, Claude Code skills https://code.claude.com/docs/en/skills, OpenClaw skills https://docs.openclaw.ai/skills, Homebrew taps https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap.
