---
name: big-arrow
description: "Point at something on the human's macOS screen with a big arrow and a sign (\"Franz, click HERE\") using the bigarrow CLI. Use whenever the human has to look at, click, type into or choose a specific spot, button, field, window, tab or menu: show me where, point to it, which button, where do I click, zeig mir wo, guide me through this UI, the human must approve or sign something, or you need the human's hand and they may not be looking at the terminal. Mandatory when it is time-critical: a code that expires, a login or payment page that times out, a build waiting on the human."
license: MIT
allowed-tools: Bash(bigarrow:*)
metadata:
  short-description: "Point at the screen with a big arrow and a sign"
---

# big-arrow

`bigarrow` draws a big, click-through arrow with a sign. It never takes the focus and needs no
permission to draw. Point at the thing itself; a line in the terminal is easy to miss.

## The one pattern

```bash
bigarrow start <target> --text "Franz, <exact action>"     # returns at once
# ... watch for the result (page changed, job continued, file appeared) ...
bigarrow stop                                               # the moment it is done
```

The arrow is tied to the app it points into: that app (window, tab) comes to the front first,
and the arrow hides while another app covers the target and returns when it is visible again.
It also ends by itself: after 300 s, when your agent session exits, and (with the hook below)
when the human answers you. Still always `stop` it yourself the moment the step is done.

The human can click the sign or the shaft to remove the arrow; clicks on the target pass
through. So skip `--close-button` (it only adds an X to the sign) unless the human asks for one.
A removed arrow means the human saw it: check the result, do not draw it again.

## Targets

| You know | Use |
|---|---|
| A label in a native or Electron app | `--element "Allow" --app "System Settings"` |
| An app or one of its windows | `--window "Safari"` / `--window "Safari:Inbox"` |
| A spot inside a Chrome tab | `--rect x,y,w,h --app "Google Chrome:<tab title>"` |
| A spot in a screenshot | `--at X,Y --app "<App>"` |

- Always give `--app` (or `--window`) when the target is inside an app, so it is raised and bound.
  `App:title` matches a window title, or else selects the tab with that title.
- Inside a Chrome page, `--element` needs Chrome started with `--force-renderer-accessibility`.
  Otherwise take the element's `getBoundingClientRect()` from Claude in Chrome and pass
  `--rect (screenX + r.x),(screenY + outerHeight - innerHeight + r.y),r.width,r.height` (100 % zoom).
- Coordinates are global top-left points. From `tinyscreenshot`: display origin + pixel x
  (source width / output width). `--display N` makes them relative to display N.
- Unsure? `bigarrow elements --app X --match "allow"`, or append `--dry-run` (draws nothing).

## Time-critical (code expires, page times out, job waits)

```bash
bigarrow start --element "Verify" --app "Safari" --text "Franz, enter the 2FA code now, it expires in 60 s" --color red --say
```

Say what and by when. One arrow per step: `stop` before pointing at the next thing.

## Sign and look

Full short sentence ("Franz, click Allow", not "here"). `--say` speaks it, `--airhorn` honks once (current volume, never unmutes). `--color` red, orange,
yellow, green, teal, blue, purple, pink, black, white or #hex. `--style box|ring` marks without
covering, `--size S|M|L`, `--duration N` for a plain timed hint (default 8 s with `point`).
Default look is a white border with a drop shadow; `--border white-black|black` and
`--border-color`, `--text-color`, `--edge-color`, `--close-color`, `--close-x-color` change it.
`--shape bend|straight|zigzag|spiral`: spiral loops once around the sign before it points.

## Errors

Exit 2 bad input, 3 target not found (the message lists what exists), 4 permission missing.
On 4 run `bigarrow doctor`: Accessibility (for `--element`, `App:title`, `--until-click`) belongs
to the app running your shell (Terminal, Ghostty, VS Code), not to bigarrow. Name that app and
the pane: System Settings > Privacy & Security > Accessibility.

## Setup once: clear arrows when the human answers

`~/.claude/settings.json`: `"hooks": {"UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bigarrow stop --hook"}]}]}`
