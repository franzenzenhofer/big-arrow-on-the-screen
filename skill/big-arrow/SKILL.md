---
name: big-arrow
description: "Point at something on the human's macOS screen with a big arrow and a sign (\"Franz, click HERE\") using the bigarrow CLI. Use whenever the human has to look at, click, type into or choose a specific spot, button, field, window or menu: show me where, point to it, which button, where do I click, zeig mir wo, guide me through this UI, the human must approve or sign something, or you need the human's hand and they may not be looking at the terminal."
license: MIT
allowed-tools: Bash(bigarrow:*) Bash(say:*)
metadata:
  short-description: "Point at the screen with a big arrow and a sign"
---

# big-arrow

`bigarrow` draws a big arrow with a sign on the screen. It is click-through, never takes the
focus, works on every display and Space, and goes away by itself. It needs no permission to
draw. Use it whenever the human must act on something on screen. A sentence in the terminal is
easy to miss; an arrow on the thing itself is not.

## Pick the target (first match wins)

| You know... | Use |
|---|---|
| The label of a button, field or menu in a native or Electron app | `--element "Reload" --app "Google Chrome"` |
| Only the app / its window | `--window "Safari"` (add `:title part` to pick a window) |
| A spot in a screenshot | `--at X,Y` (convert, see below) |
| A rectangle (a field, a region) | `--rect X,Y,W,H` (draws a box around it) |
| Where the mouse is | `--mouse` |
| An element id from `peekaboo see --json` | `--peekaboo elem_12 --snapshot snap.json` |

Not sure what `--element` will match? List what is there first:
`bigarrow elements --app "System Settings" --match "allow"`

## The three ways an arrow ends

```bash
bigarrow point --at 760,500 --text "Franz, click HERE"                 # time limit, default 8 s
bigarrow point --at 760,500 --text "Franz, click HERE" --duration 20   # longer limit
bigarrow start --at 760,500 --text "Sign here, then tell me"           # stays, returns at once
bigarrow stop                                                          # removes it (--all: every arrow)
bigarrow point --at 760,500 --text "Check this, close with X" --close-button   # human clicks the X
```

`point` blocks for its duration; use `start` (or `point --detach`) when you want to keep working.
Always `bigarrow stop` once the human has acted.

## Make sure the target is visible

If the target app may be hidden behind other windows, add `--raise` (with `--window` or
`--element ... --app`), or run `bigarrow front --app "Safari" [--window "Inbox"]` first. Never
point at something the human cannot see.

## Write a good sign

- A full, short sentence that says what to do: "Franz, click Allow", not "here".
- Add `--say` when the human is probably not looking at the screen; it speaks the sign.
- Colours: `--color red|orange|yellow|green|teal|blue|purple|pink|black|white|#RRGGBB`.
  Several arrows at once: one colour each. `--corners sharp` for square signs.
- `--size S|M|L`, `--style ring` (circle around a point), `--style box` (box around it);
  rings and boxes are border-only, so the target stays visible.
- `--shape bend|straight|zigzag`: bend is the default; straight for a calm, direct pointer;
  zigzag when it must grab attention.

## Coordinates (only for --at and --rect)

Input is **global top-left logical points**, the space Accessibility, CGWindowList and Peekaboo
report. Displays to the right or above the main display have their own offsets; all work.

- From `tinyscreenshot`: it prints `source: 1512x982` and `output: 800x520`. Then
  `point = display origin + image pixel x (source width / output width)`. The display origin
  comes from `tinyscreenshot list` (`@ (x,y)`).
- From a screenshot of one display: `--at X,Y --display N` makes the coordinates relative to
  display N (numbers from `bigarrow doctor`).
- Inside a Chrome web page, `--element` only works if Chrome runs with
  `--force-renderer-accessibility` (or VoiceOver is on); Chrome's own toolbar always works.
  Otherwise use the page's coordinates:
- From Claude in Chrome (CSS pixels in the page): run in the page
  `[screenX + rect.x, screenY + (outerHeight - innerHeight) + rect.y]` for the element's
  `getBoundingClientRect()`, then `--rect x,y,w,h`. This holds at 100 % zoom with no side panel
  or bottom bar open; check it with `--dry-run`. Prefer `--element` when the label is unique.
- Never guess. If unsure, `bigarrow point ... --dry-run --json` shows where it would point
  without drawing.

## Results and errors

- `--json` prints `{ok, pid, target:{x,y,display,source}, sign:[x,y,w,h], dismissedReason}`.
- Exit codes: 0 ok, 2 bad input, 3 target not found (the message lists what exists),
  4 permission missing.
- Exit 4: run `bigarrow doctor`. `--element`, `elements`, `--until-click` and `front --window`
  need **Accessibility**, granted to the app that runs your shell (Terminal, iTerm2, Ghostty,
  VS Code, Claude), **not** to bigarrow. Tell the human exactly that app name and the pane:
  System Settings > Privacy & Security > Accessibility. Drawing itself never needs a permission.

## Example: guide the human through a dialog

```bash
bigarrow front --app "System Settings"
bigarrow elements --app "System Settings" --match "allow" --json
bigarrow start --element "Allow" --app "System Settings" --text "Franz, click Allow" --say --color green
# ... wait until the human confirms or the setting changed ...
bigarrow stop
```
