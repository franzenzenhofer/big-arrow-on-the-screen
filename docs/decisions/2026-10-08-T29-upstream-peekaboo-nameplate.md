# T29: propose an arrow event upstream to Peekaboo and Nameplate

Date: 2026-10-08. Status: **posted** after Franz approved the exact text:
https://github.com/openclaw/Peekaboo/issues/1008 and https://github.com/steipete/Nameplate/issues/38 .
Maintainer answers: none yet.

## Evidence

- Peekaboo's visualizer has no arrow or label primitive, no sticky mode, and sets no
  `collectionBehavior`; it draws nothing unless Peekaboo.app runs
  (`docs/research/2026-10-08-peekaboo-and-steipete-tools.md`).
- Nameplate has click-through panels on every screen and a sticky `attention` banner, but no
  positioned arrow.
- `bigarrow` 0.1.0 already reads Peekaboo 4.9.0 `see --json` and `window list --json`
  (`--peekaboo`, `--peekaboo-window`), so the hand-off works today without upstream changes.

## Decision

Proposed upstream; nothing in bigarrow depends on the answer. The hand-off through `peekaboo see --json > snap.json && bigarrow point --peekaboo ...`
needs nothing from upstream. Whether to propose an `arrow` visualizer event is Franz's call once
he has seen the drafts below.

## Draft: issue for openclaw/Peekaboo

> **Title:** Idea: hand off to `bigarrow` (or add an arrow visualizer event) so agents can point at UI for the human
>
> Agents using Peekaboo can find a control (`see --json`) but have no way to show the human where it is when the human has to act (approve, sign, choose). `bigarrow` (MIT, https://github.com/franzenzenhofer/big-arrow-on-the-screen) draws a click-through, non-activating arrow with a sign at a point or rect, and already reads `see --json` 4.9.0 bounds: `peekaboo see --app Safari --json > snap.json && bigarrow point --peekaboo elem_12 --snapshot snap.json --text "Click here"`.
>
> Two options, happy with either: (1) a short note in Peekaboo's agent skill pointing to this hand-off, or (2) an `arrow` event in the visualizer (`point`, `text`, `duration`, sticky) for which our geometry and placement code (pure Swift, no dependencies) could be contributed.

## Draft: issue for steipete/Nameplate

> **Title:** Idea: a positioned arrow for `nameplate attention`
>
> `nameplate attention` is close to what agents need when they want the human's hand. What it lacks is pointing at a specific spot. `bigarrow` (MIT) does that as a standalone CLI (click-through panel, curved arrow with a sign, start/stop or click to close). Would a `--at x,y` option for `attention`, or a mention of `bigarrow` for the pointing case, be welcome?
