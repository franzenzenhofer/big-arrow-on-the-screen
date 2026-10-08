# CLAUDE.md - big-arrow-on-the-screen

macOS CLI (`bigarrow`) plus an agent skill (`big-arrow`, Claude Code and Codex) that draws a big arrow with a sign on the screen, click-through, auto-dismiss. Open source, MIT.

## State

Implemented 2026-10-08: everything in `docs/plan/PLAN.md` through M4, see `CHANGELOG.md`. `docs/plan/tickets.json` is the single source of truth for tickets; regenerate `TICKETS.md` and `report.html` with `scripts/render-tickets.py`, never edit those by hand.

## Rules

- Swift 6 strict concurrency, SwiftPM, AppKit + Core Animation. No SwiftUI for the overlay, no third-party dependencies except swift-argument-parser.
- Files target 200 lines, hard max 450. Functions under 30 lines, at most 4 parameters. No boolean parameters, no TODO comments, no commented-out code. `.swiftlint.yml` enforces this.
- No mocks. Tests hit the real window server and real Accessibility; skip with a printed reason when a permission is missing.
- Input coordinates are global top-left logical points. Flip against `NSScreen.screens[0].frame.height`, never `NSScreen.main`.
- The drawing path must never require a TCC permission. Only `--element`, `elements`, `--until-click` and `front --window` may need Accessibility, and the error must name the responsible app (terminal or IDE).
- Never call `NSApplication.run()`: its `finishLaunching()` activates a detached process and steals the focus. Use `OverlayApplication.runWithoutActivating()`.
- Gates before every commit: `swiftlint lint --strict`, `swift build -c release`, `swift test`. All green or no commit.
- Every image committed to the repo has C2PA metadata stripped and shows no personal content.
- English only in code, comments, commits and docs.

## Where to test what

- **Franz's Mac (where he works): never draw, click, raise, speak or change displays.** Only build, unit tests, `--dry-run` and offscreen renders (`--png`, `scripts/gallery.py`). Plain `swift test` is safe: screen tests only run with `BIGARROW_SCREEN_TESTS=1`.
- **CI runner** (clean desktop, Accessibility and Screen Recording granted): `ci.yml` runs all tests with screen tests on; `visual.yml` (`gh workflow run visual.yml`) records screenshots, runs `scripts/behaviour-check.sh` (clicks, follow, raise, say, second display via `scripts/virtual-display`) and records the README demo GIF.
- **Arthur Mac** (`ssh arthur-mac`): `sudo launchctl asuser 501 sudo -u arthurficial env BIGARROW_SCREEN_TESTS=1 swift test` runs the screen tests in its GUI session (no Accessibility/Screen Recording there). Its screen is often locked; then visuals are black.
- After any visual change: `python3 scripts/gallery.py .build/debug/bigarrow <out>` and look at `gallery.png` and `junctions.png` (every shape, side, size, colour; zoomed sign-to-shaft joints).

## Commands

```bash
swiftlint lint --strict && swift build -c release && swift test
swift run bigarrow point --at 760,500 --text "Franz, click HERE" --png /tmp/arrow.png   # offscreen
scripts/release.sh 0.1.1          # bump, tag, release workflow, Homebrew tap formula
```
