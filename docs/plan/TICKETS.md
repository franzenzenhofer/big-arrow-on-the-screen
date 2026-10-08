# Tickets

Generated from `tickets.json` by `scripts/render-tickets.py`. 40 tickets: 39 done, 1 not now.

## M0 Skeleton and proof

Repo, toolchain, CI, and a reproducible proof that the overlay approach works.

### T01 Repo skeleton: SwiftPM layout, MIT license, README stub, .gitignore, CLAUDE.md

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/1  
Labels: `type:infra` `size:S` `priority:P0`

**Outcome**: SwiftPM package with BigArrowCore, BigArrowOverlay, BigArrowTargeting, bigarrow and two test targets; `bigarrow --version` prints the version; `.swiftlint.yml` enforces the size rules.

Create the SwiftPM package `big-arrow-on-the-screen` with targets `BigArrowCore` (pure logic), `BigArrowOverlay` (AppKit rendering), `bigarrow` (CLI executable) and `BigArrowTests`. Add `LICENSE` (MIT, copyright Franz Enzenhofer), `README.md` stub pointing at `docs/plan/PLAN.md`, `.gitignore` (`.build/`, `*.xcodeproj`, `.DS_Store`, `.claude/worktrees/`), `CLAUDE.md` with build/test commands and the repo rules.

**Acceptance criteria**
- `swift build` succeeds on macOS 15+ with Swift 6.x, zero warnings.
- `swift test` runs (may have one placeholder test).
- `swift run bigarrow --version` prints `bigarrow 0.0.0`.
- Files target 200 lines, hard max 450 (CLAUDE.md states this).

**Depends on**: nothing.

### T02 CI: GitHub Actions macOS runner builds, lints, tests on every push

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/2  
Labels: `type:infra` `size:S` `priority:P0`

**Outcome**: `.github/workflows/ci.yml`: SwiftLint strict, release build and all tests (screen tests on) on macos-15, green; badge in README.

Add `.github/workflows/ci.yml` on `macos-15` (or newest available) running `swift build -c release`, `swift test`, and SwiftLint (or `swift-format lint`) in strict mode. Headless overlay tests must be skipped or run against a virtual display on CI (CI has a window server but no Screen Recording permission - the overlay creation itself needs no permission, so the window-level test can run).

**Acceptance criteria**
- Green check on the default branch.
- A failing test or lint warning fails the job.
- Badge in README.

### T03 Commit the feasibility probe as a documented spike (docs/spikes/overlay-probe)

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/3  
Labels: `type:research` `size:S` `priority:P1`

**Outcome**: `docs/spikes/2026-10-08-overlay-probe/` re-run on a clean CI desktop: `probe-screenshot-ci.png` (C2PA-free), `wincheck-output-ci.txt` (layer 1000, 1024x768, exit 0); README links it.

Turn the throwaway probe from the planning session into a documented spike under `docs/spikes/2026-10-08-overlay-probe/`: the ~80-line Swift file, the exact compile command, a privacy-safe screenshot (over a neutral window, not the inbox), and the window-server check output (`kCGWindowLayer = 1000`). This is reference material, not shipped code. Record the findings: `NSApplication.setActivationPolicy(.accessory)` works from a non-bundled CLI process, `.borderless` + `isOpaque=false` + `backgroundColor=.clear` + `ignoresMouseEvents=true` + `level=.screenSaver` + `collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]`.

**Acceptance criteria**
- Spike folder exists with README, source, screenshot (C2PA-free), and output log.
- README of the repo links to it under 'Why we know this works'.

## M1 MVP: point at a coordinate

bigarrow point --at X,Y --text ... draws a big arrow with a sign, click-through, auto-dismiss. Claude Code skill included.

### T04 Overlay window: click-through, always-on-top, transparent, all Spaces, per display

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/4  
Labels: `type:feature` `area:overlay` `size:M` `priority:P0`

**Outcome**: `OverlayPanel`: borderless non-activating NSPanel at .screenSaver, click-through, all Spaces, full-screen auxiliary. Verified: layer 1000, click hit-test passes through, frontmost unchanged, above a full-screen app (https://github.com/franzenzenhofer/big-arrow-on-the-screen/actions/runs/37762744052). Found and fixed: `NSApplication.run()` activated detached processes.

Implement `OverlayPanel` in `BigArrowOverlay` following the Apple DTS recipe (https://developer.apple.com/forums/thread/826308): one borderless, non-activating `NSPanel` (`styleMask: [.borderless, .nonactivatingPanel]`) per target display covering `NSScreen.frame`, `isFloatingPanel = true`, `hidesOnDeactivate = false`, `ignoresMouseEvents = true`, `level = .screenSaver` (level 1000, the only level above full-screen content), `collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`, shown with `orderFrontRegardless()`. Before that the process calls `NSApplication.shared.setActivationPolicy(.accessory)` because an unbundled executable defaults to `.prohibited`, which may not create windows (https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/prohibited). Layer-backed content view.

**Acceptance criteria**
- Overlay appears above a full-screen app, above the menu bar and in every Space; the full-screen app does not leave its Space.
- Clicks and key presses go to the app underneath. Automated: `CGWindowListCopyWindowInfo` shows the window at layer 1000; `NSWindow.windowNumber(at:belowWindowWithWindowNumber:)` hit-test at the arrow tip returns the window below the overlay.
- Works on a secondary display with negative origin (this Mac: displays at x 1512 / y -98 and x 3432 / y -98).
- Frontmost app before and after `bigarrow point` is unchanged; no Dock icon ever appears.
- No TCC prompt of any kind for the drawing path.

### T05 Coordinate model: top-left global points in, AppKit bottom-left out, multi-display aware

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/5  
Labels: `type:feature` `area:targeting` `size:M` `priority:P0`

**Outcome**: `ScreenSpace`: global top-left points, flip against the primary display height, half-open containment for shared edges, exit 2 outside every display; tests with the real 3-display geometry. `--display N` makes coordinates relative to display N.

In `BigArrowCore` add a pure `ScreenSpace` module: input coordinates are global top-left points as reported by Accessibility, CGWindowList, Peekaboo `see` and screenshots-in-points. Convert to AppKit's bottom-left window coordinates of the display that contains the point. Handle Retina scale (points, never pixels), displays with negative origins, and a point outside every display (fail fast with a clear error, exit code 2).

**Acceptance criteria**
- Unit tests with the real three-display geometry from this Mac (1512x982@2x at 0,0; 1920x1080 at 1512,-98; 1920x1080 at 3432,-98) and a single-display case.
- `--display N` overrides auto detection.
- Points on a display boundary resolve deterministically.

### T06 Arrow geometry: curved arrow from sign to target with arrowhead, pure and testable

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/6  
Labels: `type:feature` `area:overlay` `size:M` `priority:P0`

**Outcome**: `ArrowGeometry`: curved shaft, notched head along the end tangent, flared root; tip within 0.5 pt, tangent and bounds tests for all 8 sides; golden PNG test.

`ArrowGeometry` in `BigArrowCore`: given target point, sign anchor, display bounds and size (S/M/L), produce a `CGPath` for a quadratic or cubic curved shaft, a filled arrowhead oriented along the end tangent, and the sign rectangle. Stroke width, head length and curvature scale with size. No AppKit imports.

**Acceptance criteria**
- Unit tests: arrowhead tip equals the target point within 0.5pt; head angle equals the end tangent; path stays inside the display bounds for all 8 approach directions.
- Snapshot test renders the path to a PNG in a test and compares to a golden file.

### T07 Sign rendering: big rounded pill with the text, SF Rounded heavy, readable on any background

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/7  
Labels: `type:feature` `area:overlay` `size:M` `priority:P0`

**Outcome**: `SignRenderer`: SF Rounded heavy, 44 pt at M, contrast outline, wraps at 60 % width, shrinks to at most 3 lines (min 24 pt); body and text are separate layers so the arrow root sits between them.

Render the sign as a `CATextLayer`/`NSAttributedString` on a rounded-rect `CAShapeLayer`: font `NSFont.systemFont(ofSize:weight:.heavy)` with the `.rounded` design, default 44pt (size M), white text on the arrow colour, 2pt outer white stroke plus soft shadow so it reads on light and dark backgrounds. Multi-line wrap at 60% of display width. Minimum font size 24pt (size S).

**Acceptance criteria**
- Text 'Franz, click HERE' renders in one line at size M on the built-in display.
- A 120-character text wraps to at most 3 lines and never leaves the display.
- Unicode and emoji render.

### T08 CLI: `bigarrow point --at X,Y --text ... [--duration S] [--display N] [--json]`

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/8  
Labels: `type:feature` `area:cli` `size:M` `priority:P0`

**Outcome**: `bigarrow point` with all targets, `--duration`, `--display`, `--json`; exit codes 0/2/3/4, argument errors map to 2; `--help` with examples.

Use `swift-argument-parser`. `bigarrow point` is the main command; `--at X,Y` takes global top-left points. `--text` required. `--duration` seconds, default 8, `0` = until `bigarrow clear` or Ctrl-C. `--display` optional. `--json` prints a result object (`{ok, target:{x,y,display}, sign:{frame}, pid, dismissedAfter}`) to stdout; human output otherwise. Exit codes: 0 ok, 2 bad input, 3 target unresolvable, 4 permission missing. Errors are one line on stderr, machine readable with `--json`.

**Acceptance criteria**
- `bigarrow point --at 760,500 --text 'Franz, click HERE'` shows the arrow for 8 s and exits 0.
- `bigarrow point --at 99999,0 --text x` exits 2 with 'point is outside every display'.
- `--help` documents every flag with an example.

### T09 Process model: foreground run, pid file, `bigarrow clear` dismisses, SIGTERM/SIGINT clean exit

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/9  
Labels: `type:feature` `area:cli` `size:S` `priority:P0`

**Outcome**: The CLI process owns the arrow; pid files in `$TMPDIR/bigarrow`, stale ones removed; `stop`/`clear [--all|--pid]`; SIGTERM/SIGINT fade out; `--detach` and `start` return once the child is on screen. Tested: detach and stop under 0.5 s on test Macs, two arrows and `stop --all`.

The CLI process itself owns the overlay for its lifetime (no daemon, no helper app; the drawing path needs no TCC identity so a bundled app buys nothing here - contrast Nameplate's app plus JSON handoff design, which exists because its app holds state). Write `$TMPDIR/bigarrow/<pid>.json` with target, text and start time; remove on exit. `bigarrow clear [--all]` sends SIGTERM to every live pid from those files. Handle SIGTERM/SIGINT by fading out in 150 ms and exiting 0. `--detach` forks, prints the child pid as JSON and returns immediately so an agent is not blocked for the duration.

**Acceptance criteria**
- `bigarrow point ... --duration 0 --detach` returns within 300 ms; `bigarrow clear` removes the arrow within 300 ms.
- No stale pid files after a crash (files whose pid is dead are ignored and deleted).
- Two concurrent arrows are possible and `clear --all` removes both.

### T10 Claude Code skill: `big-arrow` SKILL.md that teaches an agent when and how to point

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/10  
Labels: `type:docs` `area:skill` `size:M` `priority:P0`

**Outcome**: `skill/big-arrow/SKILL.md` (one file for Claude Code and Codex), linked into `~/.claude/skills` and `~/.agents/skills`, listed by both agents, passes Codex's validator. Fresh-agent test passed: `docs/skill-tests/2026-10-08-chrome-reload.md`.

Create `skill/big-arrow/SKILL.md` following the Agent Skills standard (https://agentskills.io/specification) and Claude Code's skill reference (https://code.claude.com/docs/en/skills): frontmatter `name: big-arrow`, `description` with trigger phrases ('show me where', 'point to', 'which button', 'zeig mir wo', 'Franz, click here', guiding a human through a UI, 'where do I click'), `allowed-tools: Bash(bigarrow *) Bash(say *)`, `license: MIT`. Body under 150 lines: the decision tree (coordinate from a screenshot vs element vs window vs mouse), the exact commands, how to get coordinates from `tinyscreenshot` (image points times the downscale factor), `peekaboo see --json` or Claude in Chrome, the rule to always put a full sentence on the sign, to add `--say` when the human is likely not looking, to run `bigarrow doctor --json` on the first permission error, and to `bigarrow clear` when the human has acted. Document the TCC rule: Accessibility is granted to the terminal or IDE that runs the agent, not to `bigarrow`.

**Acceptance criteria**
- Symlinked into `~/.claude/skills/big-arrow` and listed by Claude Code.
- A fresh subagent given 'show Franz where the Reload button in Chrome is' uses the skill and runs a correct `bigarrow point` command (record the transcript in `docs/skill-tests/`).
- Skill text contains no coordinates specific to this Mac and stays under 500 lines (Claude Code limit).

### T11 Integration test harness: spawn the CLI, assert window level, pixel colour at the tip, clean exit

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/11  
Labels: `type:test` `size:M` `priority:P1`

**Outcome**: `Tests/IntegrationTests`: spawns the real binary, checks layer 1000, click-through, focus, sign pixel colour (skipped without Screen Recording), timing. Opt-in with `BIGARROW_SCREEN_TESTS=1`; CI sets it.

`Tests/IntegrationTests`: run the built `bigarrow` binary with `--at`, then (a) `CGWindowListCopyWindowInfo` contains a window owned by `bigarrow` at layer 1000 covering the display, (b) a `CGDisplayCreateImage`/`screencapture` crop at the arrow tip is the arrow colour (requires Screen Recording for the test runner; skip with a clear message when missing), (c) process exits 0 after `--duration 1`. No mocks: the real window server.

**Acceptance criteria**
- Test passes locally with permissions granted; on CI the colour check is skipped with reason, the window-level check runs.
- Test runtime under 10 s.

## M2 Targeting: window, element, mouse, rect

Resolve targets by app/window title, Accessibility element, mouse position or rect. Multi-display correct.

### T12 Target by window: `--window 'App Name'[:title substring]` points at the window's centre or title bar

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/12  
Labels: `type:feature` `area:targeting` `size:M` `priority:P0`

**Outcome**: `--window App[:title]` by pid via NSWorkspace and CGWindowList, no permission; title match needs Screen Recording (exit 4); windows parked off-screen are skipped; unknown app exits 3 listing apps with windows; fixture tests.

Resolve the window without any permission: match the app via `NSWorkspace.shared.runningApplications` (`localizedName`, `bundleIdentifier`, case-insensitive) to a pid, then take that pid's on-screen layer-0 windows from `CGWindowListCopyWindowInfo` by `kCGWindowOwnerPID` and use `kCGWindowBounds` (top-left global points). Do NOT rely on `kCGWindowOwnerName` or `kCGWindowName`: on macOS 26 those are nil or empty without Screen Recording (https://developer.apple.com/forums/thread/839069, https://developer.apple.com/forums/thread/126860). Optional `:title` substring matching uses `kCGWindowName` only when `CGPreflightScreenCaptureAccess()` is true, otherwise exit 4 with a message naming the permission. Ambiguity: pick the first window in list order (frontmost), report the count in `--json`. `--anchor center|title|top-left|top-right|bottom-left|bottom-right` chooses the point inside the window.

**Acceptance criteria**
- `bigarrow point --window Safari --text 'this one'` points at Safari's front window without Screen Recording.
- Unknown app exits 3 and the message lists the running apps with visible windows.
- Unit tests for the matcher with a recorded running-apps and window-list fixture.

### T13 Target by Accessibility element: `--element 'Save' [--app Safari] [--role button]`

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/13  
Labels: `type:feature` `area:targeting` `size:L` `priority:P0`

**Outcome**: `--element` walks the AX tree (windows first, depth 25, 2 s budget), ranks exact > prefix > substring, visible first; exit 4 names the responsible app; Calculator fixture tests; live on CI (Allow button).

Walk the AX tree of the app (`AXUIElementCreateApplication`, children, `kAXRoleAttribute`, `kAXTitleAttribute`, `kAXDescriptionAttribute`, `kAXValueAttribute`), match label text (case-insensitive, substring, optional role filter), read `kAXPositionAttribute` and `kAXSizeAttribute` (already top-left global points). Depth limit 25, time budget 2 s, prefer enabled and visible elements. Multiple matches: choose the first visible one, report all in `--json`. Needs Accessibility permission for the PARENT process (Terminal, iTerm, Claude Code); detect with `AXIsProcessTrustedWithOptions` and exit 4 with the exact System Settings path.

**Acceptance criteria**
- `bigarrow point --element 'Reload' --app 'Google Chrome' --text 'click reload'` points at the reload button.
- Without permission the error names the parent app that must be granted.
- Unit tests for the matcher on a recorded AX snapshot fixture (JSON) and one live test when permission is present.

### T14 Target by mouse and by rect: `--mouse`, `--rect x,y,w,h` with highlight box

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/14  
Labels: `type:feature` `area:targeting` `size:S` `priority:P1`

**Outcome**: `--mouse` (within 2 pt, integration test) and `--rect` with a border-only box; the tip hits the box edge nearest the sign.

`--mouse` reads `NSEvent.mouseLocation` (convert from AppKit space) and points at the cursor. `--rect x,y,w,h` draws a rounded highlight box with glow around the rect and points at its nearest edge midpoint. Rect and element targeting share the box renderer.

**Acceptance criteria**
- `bigarrow point --mouse --text 'here'` tip is within 2pt of the cursor.
- `--rect` box is visible around a given screenshot region on the correct display.

### T15 Peekaboo adapter: accept `peekaboo see --json` element ids and bounds as targets

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/15  
Labels: `type:feature` `area:targeting` `size:M` `priority:P1`

**Outcome**: Peekaboo adapter for `see --json` and `window list --json` 4.9.0 (recorded with the official 4.9.0 binary), bounds-less 3.0 snapshots rejected with the minimum version; stdin or `--snapshot`.

`bigarrow point --peekaboo <elementId>` reading a Peekaboo `see --json` snapshot from `--snapshot <path>` or stdin: parse `data.ui_elements[]` (`id`, `role`, `label`, `title`, `bounds {x,y,width,height}`), point at the element's centre. Peekaboo 4.9.0 reports `bounds` as global top-left logical points (verified in `openclaw/Peekaboo` `SeeTool.swift:491` and `docs/MCP.md`, see `docs/research/2026-10-08-peekaboo-and-steipete-tools.md`), which is exactly this tool's input space, so no conversion beyond the standard flip. Thin optional adapter in `BigArrowCore/Adapters/Peekaboo.swift`, no build-time dependency on Peekaboo. The installed Peekaboo 3.0.0-beta3 omits `bounds` (verified 2026-10-08): reject it with a clear message naming the minimum version. Also accept `peekaboo window list --app X --json` (`windows[].bounds`) for `--peekaboo-window <index>`.

**Acceptance criteria**
- Fixture-based unit tests for `see` 4.9.0, `window list` 4.9.0 and the bounds-less 3.0 shape (error path).
- Documented one-liner in the skill: `peekaboo see --app Safari --json > snap.json && bigarrow point --peekaboo B3 --snapshot snap.json --text '...'`.

### T16 Multi-display and Spaces behaviour verified: full-screen apps, Stage Manager, display disconnect

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/16  
Labels: `type:test` `area:overlay` `size:M` `priority:P1`

**Outcome**: `docs/verification/multi-display.md`: full screen, Stage Manager, Space switch, second display, 2x mode, unplug mid-arrow, all pass on CI (https://github.com/franzenzenhofer/big-arrow-on-the-screen/actions/runs/37762744052).

Manual + scripted verification matrix: overlay over a full-screen Safari, over a Stage Manager stage, after switching Spaces while the arrow is up, when the target display is unplugged while the arrow is up (window must close, process exits 0), on a display with scale 1 and scale 2. Record results in `docs/verification/multi-display.md` with screenshots.

**Acceptance criteria**
- Every matrix cell has a dated result; failures become tickets.

### T32 Bring the target app and window to the front: `front` and `--raise`

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: `bigarrow front --app X [--window title]`, `point --raise`; dry runs never raise (bug found by the skill test); CI check.

Agents must not point at something hidden behind the terminal.

### T37 `bigarrow elements`: list what `--element` can match

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: Used by the fresh-agent skill test.

Agents look before they point.

### T40 `--element` inside web content (Electron, Chrome)

**Status: Done**  
Labels: `type:feature` `priority:P2` `size:S`

**Outcome**: Electron apps expose their web tree after `AXManualAccessibility` (verified with Claude.app); Chrome 2026 rejects both requests and exposes pages only with `--force-renderer-accessibility` or VoiceOver (verified on the test Mac); documented in the README FAQ and the skill.

Agents point at web pages most of the time.

## M3 Beauty and behaviour

Animations, auto placement, styles, follow moving targets, speak the sign, dismiss on click.

### T17 Animations: draw-on stroke, spring-in sign, pulsing head, fade-out

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/17  
Labels: `type:feature` `area:overlay` `size:M` `priority:P1`

**Outcome**: Draw-on stroke, spring head and sign, pulsing head, fade out; Reduce Motion and `--no-animation`. Demo GIF `docs/images/demo.gif`; 1.4 % CPU while pulsing (CI).

Core Animation only: `CAShapeLayer.strokeEnd` from 0 to 1 over 450 ms (ease-out) for the shaft, arrowhead scales in with `CASpringAnimation` at the end of the stroke, the sign springs in from 0.8 scale, head pulses 1.0 to 1.08 every 900 ms while shown, 200 ms fade on dismiss. `--no-animation` renders the final frame directly. Respect `NSWorkspace.accessibilityDisplayShouldReduceMotion`.

**Acceptance criteria**
- Recorded GIF in `docs/images/` shows the sequence.
- Reduce Motion on: no pulse, 100 ms fades only.
- CPU of the process under 3% while idle-pulsing.

### T18 Auto placement: choose the arrow approach direction and sign position with the most free space

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/18  
Labels: `type:feature` `area:overlay` `size:M` `priority:P1`

**Outcome**: `Placement`: 8 sides scored by free space, menu bar and Dock avoided, never covers the target (a forced side that does not fit falls back); corner and edge tests; deterministic.

Given the target and display bounds, evaluate the 8 approach directions, score by free space for the sign, distance from display edges and from the menu bar, and never cover the target itself. `--from top-left|top|...|auto` overrides. Keep it a pure function in `BigArrowCore/Placement.swift`.

**Acceptance criteria**
- Unit tests: target in each corner and at each edge midpoint yields a sign fully on screen and not overlapping a 120x120 pt zone around the target.
- Deterministic for equal inputs.

### T19 Styles and sizes: `--style arrow|ring|box`, `--size S|M|L`, `--color`, dark/light contrast

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/19  
Labels: `type:feature` `area:overlay` `size:S` `priority:P2`

**Outcome**: `--style arrow|ring|box`, `--size S|M|L`, ten colour presets and hex with automatic contrast; `docs/images/gallery.png`; invalid colours exit 2 naming the formats.

Three styles: curved arrow (default), pulsing ring around the target, highlight box. Sizes scale stroke, head, font. `--color` accepts named presets (`red`, `orange`, `blue`, `green`) or hex. Every style keeps the white outline for contrast.

**Acceptance criteria**
- Screenshot of each style x size in `docs/images/styles.png`.
- Invalid colour exits 2 with the accepted formats.

### T20 Speak the sign: `--say` speaks the text via macOS `say`, `--voice` optional

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/20  
Labels: `type:feature` `area:cli` `size:S` `priority:P1`

**Outcome**: `--say [--voice]` speaks after the arrow is up; `stop` silences it within 300 ms (CI check).

When `--say` is set, run `/usr/bin/say` with the sign text (and `--voice` when given) concurrently with showing the arrow, never blocking the draw. Kill `say` on dismiss. Document that this is how an agent gets Franz's attention when he is not looking at the screen.

**Acceptance criteria**
- Arrow appears before speech starts (no visible delay).
- `bigarrow clear` stops speech within 300 ms.

### T21 Follow a moving target: re-resolve `--window`/`--element` every 250 ms while shown

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/21  
Labels: `type:feature` `area:targeting` `size:M` `priority:P2`

**Outcome**: `--follow` re-resolves window and element targets every 250 ms; `targetGone` after 2 s of absence; CI check moves the window and closes it.

With `--follow`, re-resolve the target on a timer and animate the arrow tip to the new point; hide the arrow when the target disappears (window closed, element gone) and exit 0 after 2 s of absence unless `--duration 0`. Only for window and element targets.

**Acceptance criteria**
- Dragging the target window moves the arrow within one frame of the next tick.
- Closing the window ends the process with exit 0 and `dismissedReason: targetGone` in `--json`.

### T22 Dismiss on click: `--until-click` removes the arrow when the human clicks the target area

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/22  
Labels: `type:feature` `area:cli` `size:M` `priority:P2`

**Outcome**: `--until-click` / `--until-any-click` via a listen-only event tap; a real click on the target ends it with `clicked` (CI).

Install a passive `CGEvent` tap (`.listenOnly`, `kCGEventLeftMouseDown`) and dismiss when a click lands within the target rect (or anywhere with `--until-any-click`). Requires Accessibility permission; without it, exit 4 unless `--duration` is also given, in which case fall back to the timer and warn.

**Acceptance criteria**
- Click on the target dismisses the arrow and prints `dismissedReason: clicked`.
- No key or mouse events are consumed or altered (listen-only tap).

### T23 `bigarrow doctor`: permissions, parent process identity, displays, Peekaboo presence

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/23  
Labels: `type:feature` `area:cli` `size:S` `priority:P1`

**Outcome**: `bigarrow doctor [--json] [--require ...] [--open-settings] [--request-accessibility]`: permissions, responsible app from the parent chain, displays, Peekaboo, macOS.

Prints: Accessibility trusted yes/no via `AXIsProcessTrusted()` and WHICH app owns that grant (walk the parent chain to the responsible process: Terminal, iTerm2, Claude Code binary, VS Code; name and bundle id), Screen Recording via `CGPreflightScreenCaptureAccess()`, display list (id, origin, size in points, scale, `screensHaveSeparateSpaces`), whether `peekaboo` is on PATH and its version, macOS version. `--json` for agents. `--open-settings` opens the Accessibility pane (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`). `--request-accessibility` calls `AXIsProcessTrustedWithOptions` with the prompt option.

**Acceptance criteria**
- Output matches the current machine state (cross-check against `peekaboo permissions`).
- Exit code 0 when every permission the requested features need is present, 4 otherwise, and the message names the responsible app to grant.

### T31 Three lifetimes: time limit, start/stop, close button (X)

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: A real click on the X ends the arrow and keeps the focus (CI); `start` returns at once; `stop` removes it.

`--duration`, `bigarrow start` + `bigarrow stop`, and `--close-button`: a separate tiny non-activating panel that takes the click while the arrow stays click-through.

### T33 Shaft shapes: bend, straight, zigzag

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: Shape tests for all sides; gallery.

`--shape bend|straight|zigzag`; the zigzag leaves the sign straight out and runs straight into the head.

### T34 One-piece arrow: no seams, flared joint into the sign, round or sharp sign corners

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: Root smoothness tests (tangent continuity, edge tangency, no rounded corners); junction zoom sheet `docs/images/junctions.png`.

Outlines under fills, shaft grows out of the sign through a fillet that stays on a straight part of the edge; `--corners round|sharp`.

### T35 Border-only target marks and more colours

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: Preset tests; gallery.

Rings and boxes without fill so the target stays visible; ten presets plus hex, dark contrast on light colours.

### T36 Visual QA without touching anybody's screen

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: Gallery and demo committed; screen tests opt-in.

`--png` renders offscreen; `scripts/gallery.py` renders every combination and zooms into every joint; `visual.yml` records on a clean runner.

### T39 Several arrows at once without overlapping signs

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: New arrows read the live arrows' sign frames from the pid registry and avoid them, move further out when crowded, and minimize overlap as the last resort; placement test; `docs/images/hero-hn.png` is five independent arrows.

Found while shooting the Hacker News hero: independent `bigarrow start` calls placed their signs on top of each other.

## M4 Distribution

Homebrew formula in franzenzenhofer/homebrew-tap, release automation, skill installer, README with demo GIF.

### T24 Homebrew formula in franzenzenhofer/homebrew-tap: `brew install franzenzenhofer/tap/bigarrow`

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/24  
Labels: `type:infra` `area:distribution` `size:M` `priority:P0`

**Outcome**: `scripts/bigarrow.rb.template` and `scripts/release.sh` write `Formula/bigarrow.rb` in franzenzenhofer/homebrew-tap; `release.yml` builds an ad-hoc signed universal binary.

Add `Formula/bigarrow.rb` to the existing tap (pattern: `Formula/openit.rb`): build from source with `swift build -c release --disable-sandbox`, install the binary and the skill folder into `share/bigarrow/skill`, `depends_on :macos`, `depends_on xcode: ['16.0', :build]`. Formula `test do` runs `bigarrow --version` and `bigarrow doctor --json`. Also a `release.yml` in this repo that tags, builds an ad-hoc signed universal binary, attaches it to the GitHub release, and opens the tap bump PR. Notarization is not required for a formula built from source; document that the optional prebuilt binary is ad-hoc signed (`codesign --sign -`) and what Gatekeeper does with it.

**Acceptance criteria**
- `brew install franzenzenhofer/tap/bigarrow` works on a clean Mac (test on Arthur Mac over SSH).
- `brew test bigarrow` passes.
- `brew audit --strict bigarrow` passes.

### T25 Skill installer: `bigarrow install-skill [--claude|--openclaw] [--force]` symlinks SKILL.md into the agent's skills dir

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/25  
Labels: `type:feature` `area:skill` `size:S` `priority:P1`

**Outcome**: `bigarrow install-skill [--claude|--codex] [--force]` copies the skill folder into `~/.claude/skills/big-arrow` and `~/.agents/skills/big-arrow`; idempotent; recognises a linked checkout.

Mirror the `tinyscreenshot install-skill` approach: copy or symlink `share/bigarrow/skill/big-arrow` into `~/.claude/skills/big-arrow` (and the OpenClaw skills dir when `--openclaw`). Idempotent, prints what it did, refuses to overwrite a modified file without `--force`.

**Acceptance criteria**
- After install, Claude Code lists the `big-arrow` skill in a new session.
- Running twice changes nothing and says so.

### T26 README with demo GIF, 30-second install, agent usage, FAQ (permissions, click-through, multi-display)

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/26  
Labels: `type:docs` `size:M` `priority:P0`

**Outcome**: README with demo GIF, use cases, install, the three commands, looks, FAQ, evidence, prior art; every command shown was run.

README structure like `tinyscreenshot`: one-paragraph pitch ('an AI agent points at your screen'), demo GIF (recorded with the real tool over a neutral window, C2PA stripped), install (`brew`), the three commands an agent needs, the skill install, FAQ, prior art section crediting Peekaboo's visualizer and the macOS annotation tools researched in the plan, MIT badge, CI badge.

**Acceptance criteria**
- Every command in the README was executed and its output matches.
- GIF under 3 MB, no C2PA metadata (`grep -c c2pa` = 0).

### T27 First tagged release v0.1.0 with changelog

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/27  
Labels: `type:infra` `area:distribution` `size:S` `priority:P0`

**Outcome**: v0.1.0 tagged with CHANGELOG and release assets; tap formula bumped.

`CHANGELOG.md` (Keep a Changelog), tag `v0.1.0`, GitHub release with notes and the ad-hoc signed binary, tap formula bumped to the tag's tarball sha256.

**Acceptance criteria**
- `brew upgrade bigarrow` on this Mac and Arthur Mac results in `bigarrow --version` = `bigarrow 0.1.0`.

### T38 Funny real-world scenes for the README

**Status: Done**  
Labels: `type:feature` `priority:P1` `size:M`

**Outcome**: `docs/images/scenes/`.

Staged neutral dialogs (node_modules, cookies, 2FA, Friday deploy, which button, permissions) recorded on a clean runner.

## M5 Ecosystem

Peekaboo adapter, Claude Code and Codex skill, MCP server evaluation.

### T28 Codex skill format next to Claude Code (instead of an OpenClaw variant)

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/28  
Labels: `type:docs` `area:skill` `size:S` `priority:P2`

**Outcome**: Replaced by Franz on 2026-10-08: no OpenClaw variant; one SKILL.md in the Agent Skills format serves Claude Code and Codex (plus `agents/openai.yaml` for Codex).

Generate the OpenClaw variant of the skill from the same source body: frontmatter per https://docs.openclaw.ai/skills with `metadata.openclaw.os: [darwin]`, `requires.bins: [bigarrow]`, and an `install` entry of kind `brew` with `formula: franzenzenhofer/tap/bigarrow`. Validate with `openclaw skills check`, publish with `clawhub skill publish ./skill/big-arrow --dry-run` then for real (https://docs.openclaw.ai/clawhub/publishing). One source, two outputs via a build step; never two hand-maintained copies.

**Acceptance criteria**
- `openclaw skills install @franzenzenhofer/big-arrow` (or the slug ClawHub assigns) installs and `openclaw skills info` shows the brew requirement.
- Diff between the two generated SKILL.md bodies is frontmatter only.

### T29 Evaluate upstreaming an `arrow` visualizer event into openclaw/peekaboo

**Status: Done** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/29  
Labels: `type:research` `size:S` `priority:P2`

**Outcome**: Proposals posted 2026-10-08 after Franz approved the text: https://github.com/openclaw/Peekaboo/issues/1008 and https://github.com/steipete/Nameplate/issues/38. Decision record: `docs/decisions/2026-10-08-T29-upstream-peekaboo-nameplate.md`; answers get recorded there.

Decision record after v0.1.0 ships: open an issue in `openclaw/Peekaboo` proposing an `arrow` visualizer event (`point`, `text`, `duration`, sticky flag) backed by this project's geometry and placement code, or a documented `peekaboo see --json` to `bigarrow` hand-off in Peekaboo's agent skill. Evidence base: Peekaboo's visualizer has no arrow or label primitive, no sticky mode, and sets no `collectionBehavior` (see `docs/research/2026-10-08-peekaboo-and-steipete-tools.md`). Also consider the same proposal for `steipete/Nameplate` (`nameplate attention` already has sticky semantics but no positioned arrow). Record the maintainers' answers in `docs/decisions/`.

**Acceptance criteria**
- Issue links and a yes/no/later decision recorded for both projects.

### T30 Evaluate a minimal MCP server wrapper (`bigarrow mcp`) for non-CLI agents

**Status: Not now** · Issue: https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues/30  
Labels: `type:research` `size:S` `priority:P2`

**Outcome**: `docs/decisions/2026-10-08-T30-mcp-server.md`: both target agents run shell commands; no consumer without a shell was named.

Spike whether a stdio MCP server exposing `point`, `clear`, `doctor` adds value for agents that cannot run shell commands (e.g. desktop Claude without Claude Code). Only build it if a real consumer exists; otherwise close with the decision.

**Acceptance criteria**
- Decision record with the consumer named, or 'not now' with reason.
