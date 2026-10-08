# big-arrow-on-the-screen

[![CI](https://github.com/franzenzenhofer/big-arrow-on-the-screen/actions/workflows/ci.yml/badge.svg)](https://github.com/franzenzenhofer/big-arrow-on-the-screen/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> An AI agent points at your screen. A big, good-looking arrow with a sign ("Franz, click HERE"), click-through, gone by itself. macOS. One shell command. MIT.

![bigarrow pointing at a dialog's Allow button](docs/images/demo.gif)

Agents like Claude Code and Codex can see the screen and act on it, but when they need the human to do something ("click Allow", "pick the second account", "sign here") all they can do is write a sentence into a terminal the human is not looking at. `bigarrow` gives them a hand to point with.

- **One binary, no app to keep running.** The CLI process owns the arrow while it is shown.
- **Never in the way.** Click-through, never takes the focus, above full-screen apps, on every Space and every display.
- **Needs no permission to draw.** Only pointing at a UI element by its label uses Accessibility.
- **A skill for Claude Code and Codex** teaches agents when and how to point.

## Install

```bash
brew install franzenzenhofer/tap/bigarrow
bigarrow install-skill          # Claude Code (~/.claude/skills) and Codex (~/.agents/skills)
```

From source: `swift build -c release` (Xcode 16 or newer, macOS 14 or newer), binary at `.build/release/bigarrow`.

## The commands an agent needs

```bash
bigarrow point --element "Allow" --app "System Settings" --text "Franz, click Allow"   # by label
bigarrow point --at 760,500 --text "Franz, click HERE"                                 # by coordinate
bigarrow start --window "Safari:Inbox" --raise --text "This window" && bigarrow stop   # stays until stop
```

Three ways an arrow ends:

| | |
|---|---|
| Time limit | `bigarrow point ... --duration 10` (default 8 s) |
| Start and stop | `bigarrow start ...` returns at once; `bigarrow stop` (or `stop --all`) removes it |
| Human closes it | `bigarrow point ... --close-button` puts a clickable X on the sign |

Targets: `--at X,Y`, `--rect X,Y,W,H`, `--mouse`, `--window App[:title]`, `--element Label --app App`, `--peekaboo ID --snapshot see.json` (from `peekaboo see --json`). Coordinates are global top-left logical points, the space Accessibility, CGWindowList and Peekaboo report. `--display N` makes `--at`/`--rect` relative to one display.

`bigarrow front --app X` or `point --raise` bring the target's app to the front first. `bigarrow elements --app X` lists what `--element` can match. `bigarrow doctor` shows permissions, who owns them, and the displays.

Every command takes `--json`. Exit codes: 0 ok, 2 bad input, 3 target not found, 4 permission missing.

## Looks

![every style, shape, size and colour](docs/images/gallery.png)

- `--shape bend|straight|zigzag`, `--style arrow|ring|box` (rings and boxes are border-only), `--size S|M|L`, `--corners round|sharp`
- `--color red|orange|yellow|green|teal|blue|purple|pink|black|white|#RRGGBB`; light colours get a dark outline and text
- `--say` speaks the sign (for when the human is not looking), `--follow` moves with a window or element, `--until-click` ends on a click
- `--png file.png` renders the arrow into an image instead of the screen

The shaft grows out of the sign through a flared joint that never touches a rounded corner; `scripts/gallery.py` renders every combination offscreen and zooms into each joint ([junctions](docs/images/junctions.png)).

## Permissions (FAQ)

- **Drawing needs nothing.** No Screen Recording, no Accessibility.
- **`--element`, `elements`, `--until-click`, `front --window`** need Accessibility, which macOS grants to the app that runs your shell (Terminal, iTerm2, Ghostty, VS Code, Claude), never to `bigarrow` itself. `bigarrow doctor` names that app; exit code 4 says the same.
- **`--window App:title`** reads window titles, which macOS 26 hides without Screen Recording. `--window App` alone needs nothing (the app is matched by its process, not by name).
- **Does it click for me?** No. It never clicks, types or captures. It only points.
- **Multiple displays?** Yes, any arrangement, including displays above or left of the main one (negative coordinates). Each arrow is drawn on the display that contains its target.

## Why we know it works

- 72 automated tests: geometry, placement, joint smoothness, a golden image, recorded window-server, Accessibility and Peekaboo 4.9.0 fixtures, and tests against the real window server (window level 1000, clicks pass through, the focus never moves, detach and stop timing). CI runs them on macOS 15; they also pass on macOS 26 and 27.
- A visual workflow records every arrow over a neutral dialog on a clean runner ([visual.yml](.github/workflows/visual.yml)).
- The planning spike: `docs/spikes/2026-10-08-overlay-probe/`.

## Plan, decisions, research

`docs/plan/PLAN.md` (goal, architecture, risks), `docs/plan/TICKETS.md` (generated from `docs/plan/tickets.json`), `docs/research/` (verified facts with links), `docs/decisions/`, `docs/skill-tests/`.

## Prior art and thanks

Peekaboo's visualizer (https://github.com/openclaw/Peekaboo) and Nameplate (https://github.com/steipete/Nameplate) by Peter Steinberger showed the overlay window recipe and the agent-skill packaging. Neither draws a pointing arrow with a label, which is the gap this project fills. `bigarrow` reads Peekaboo's `see --json` as an optional target source.

## License

MIT, see `LICENSE`.
