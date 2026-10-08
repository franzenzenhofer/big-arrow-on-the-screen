# big-arrow-on-the-screen

> An AI agent points at your screen. A big, good-looking arrow with a sign ("Franz, click HERE"), click-through, gone by itself. macOS. One shell command. MIT.

**Status (2026-10-08): planning complete, no implementation yet.** The plan, the research behind it and all 30 tickets are in this repo and in the [issues](https://github.com/franzenzenhofer/big-arrow-on-the-screen/issues).

## Why

Agents like Claude Code and OpenClaw can see the screen and act on it, but when they need the human to do something ("click Allow", "pick the second account", "sign here") all they can do is write a sentence into a terminal the human is not looking at. This tool gives them a hand to point with.

## What it will be

- `bigarrow`, a small Swift CLI (one binary, no app to keep running, no permission needed to draw).
- A Claude Code skill (`big-arrow`) and an OpenClaw skill that teach the agent when and how to point.
- Targets: a coordinate, the mouse, a rectangle, a window by app name, a UI element by label (Accessibility), or an element id from Peekaboo's `see --json`.

```bash
bigarrow point --at 760,500 --text "Franz, click HERE"
bigarrow point --element "Reload" --app "Google Chrome" --text "Click reload" --say
bigarrow clear
```

## Why we know it works

A throwaway probe written during planning drew the arrow and sign above Chrome at window level 1000 with no Dock icon, no focus change and no permission prompt: `docs/spikes/2026-10-08-overlay-probe/`.

## Plan and tickets

- `docs/plan/PLAN.md` - goal, status quo, approaches, architecture, effort, risks
- `docs/plan/TICKETS.md` - all tickets with acceptance criteria (generated from `docs/plan/tickets.json`)
- `docs/research/` - verified facts with URLs: Apple overlay APIs, coordinate systems, Accessibility and TCC, Peekaboo and Nameplate internals, prior art, Homebrew, skill formats

## Prior art and thanks

Peekaboo (https://github.com/openclaw/Peekaboo) and Nameplate (https://github.com/steipete/Nameplate) by Peter Steinberger showed the overlay window recipe and the agent-skill packaging. Neither draws a pointing arrow with a label, which is the gap this project fills.

## License

MIT, see `LICENSE`.
