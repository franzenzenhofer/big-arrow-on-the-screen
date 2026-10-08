# CLAUDE.md - big-arrow-on-the-screen

macOS CLI (`bigarrow`) plus AI-agent skill that draws a big arrow with a sign on the screen, click-through, auto-dismiss. Open source, MIT.

## State

Planning complete 2026-10-08, implementation not started. Read `docs/plan/PLAN.md` first, then the GitHub issue you are working on. `docs/plan/tickets.json` is the single source of truth for tickets; regenerate `TICKETS.md` and `report.html` from it, never edit those by hand.

## Rules

- Swift 6 strict concurrency, SwiftPM, AppKit + Core Animation. No SwiftUI for the overlay, no third-party dependencies except swift-argument-parser.
- Files target 200 lines, hard max 450. Functions under 30 lines, at most 4 parameters. No boolean parameters, no TODO comments, no commented-out code.
- No mocks. Tests hit the real window server and real Accessibility; skip with a printed reason when a permission is missing.
- Input coordinates are global top-left logical points. Flip against `NSScreen.screens[0].frame.height`, never `NSScreen.main`.
- The drawing path must never require a TCC permission. Only `--element` may need Accessibility, and the error must name the responsible app (terminal or IDE).
- Gates before every commit: `swift build -c release`, `swift test`, lint. All green or no commit.
- Every image committed to the repo has C2PA metadata stripped and shows no personal content.
- English only in code, comments, commits and docs.

## Commands (once T01 lands)

```bash
swift build -c release
swift test
swift run bigarrow point --at 760,500 --text "Franz, click HERE"
```
