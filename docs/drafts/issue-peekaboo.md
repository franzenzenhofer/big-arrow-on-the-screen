Repo: openclaw/Peekaboo
Title: Idea: hand off to bigarrow (or add an arrow visualizer event) so agents can point at UI for the human

Agents using Peekaboo can find a control (`see --json`) but have no way to show the human where it is when the human has to act (approve, sign, choose). `bigarrow` (MIT, https://github.com/franzenzenhofer/big-arrow-on-the-screen) draws a click-through, non-activating arrow with a sign at a point or rect, and already reads `see --json` 4.9.0 bounds:

    peekaboo see --app Safari --json > snap.json && bigarrow point --peekaboo elem_12 --snapshot snap.json --text "Click here"

Two options, happy with either: (1) a short note in Peekaboo's agent skill pointing to this hand-off, or (2) an `arrow` event in the visualizer (`point`, `text`, `duration`, sticky) for which our geometry and placement code (pure Swift, no dependencies) could be contributed.
