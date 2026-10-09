# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-10-09

### Changed
- The default look is the white border with a drop shadow again, exactly as in 0.1.x.
- `--border shadow|white-black|black` replaces `--shadow`: `white-black` is the white border with a thin black edge outside it, `black` a thin black outline only.
- The X of `--close-button` is a white circle with the X in the arrow colour by default.

### Added
- `--border-color`, `--text-color`, `--edge-color`, `--close-color`, `--close-x-color`: every colour of the arrow can be set; left out, each picks a readable colour.
- The README shows every border style and colour option (`scripts/gallery.py` writes `looks.png`).

### Fixed
- The sign's black edge no longer cuts through the white border where the shaft meets the sign: it is drawn below every white border.
- The drop shadow is never cut off: PNG renders keep a margin wider than the shadow reaches, and signs keep 24 pt from the screen edge (a test fails if the shadow touches the PNG's edge).

## [0.2.1] - 2026-10-09

### Fixed
- The white contrast border is back (0.2.0 replaced it with a thin black outline by mistake). Without a shadow, a thin black edge now runs outside the white border; `--shadow` keeps the white border and uses the shadow instead of the black edge. Every black edge sits below every white border, so the flared joint has no seam.

## [0.2.0] - 2026-10-09

### Added
- `--app App[:window or tab title]` works with every target. A title that matches no window selects the tab with that title (Chrome, Safari) and raises its window.
- A bound arrow (`--app` or `--window`) hides while another app's window covers its target and comes back when the target is visible again.
- An arrow ends when the agent process that drew it exits (`CLAUDE_PID`, or `BIGARROW_OWNER_PID`); new dismissal reason `ownerGone`.
- `bigarrow stop --session ID` and `bigarrow stop --hook` (Claude Code hook payload on stdin, silent) clear the arrows of one agent session.
- A click on the sign or the shaft removes the arrow (it dims slightly under the pointer); clicks near the head and on the target pass through. No permission needed.
- `--shadow`: an optional short, soft drop shadow.

### Changed
- The target's app, window or tab comes to the front by default; `--no-raise` opts out. `--raise` is gone.
- `start`, `--close-button` and `--until-click` arrows end after 300 s unless `--duration` says otherwise; `--duration 0` is the only way to keep one up indefinitely.
- Look: a 1.5 pt black outline (white on near-black arrows) replaces the white contrast outline, and there is no drop shadow by default.
- `--close-button` draws the X inside the sign's right end instead of a separate panel on its corner, so it never covers text or hangs off the screen.
- Skill: one pattern (`start`, watch, `stop`), no close button by default, `--app` on every in-app target, the hook setup, about a third shorter.

## [0.1.2] - 2026-10-08

### Changed
- Skill: a "Time-critical" section and a mandatory trigger for expiring codes, login or payment pages that time out, and jobs waiting on the human (red, spoken, close button, `stop` afterwards).

## [0.1.1] - 2026-10-08

### Changed
- Several arrows at once keep their signs clear of each other (live arrows publish their sign frames); when the screen is crowded a sign moves further out, and overlaps as little as possible only when nothing else fits.
- `--from` is a preference: a side where the sign does not fit falls back to the roomiest side, so an arrow never covers its own target.
- When several running apps share a name (two Chrome instances), `--element`, `elements`, `front` and `--raise` use the one the human sees.
- `--element` asks Electron apps for their web content tree (`AXManualAccessibility`) and searches deeper and longer, for web pages.

### Fixed
- `--window` skips windows an app parks off-screen.

## [0.1.0] - 2026-10-08

### Added
- `bigarrow point`: a big arrow with a sign, click-through, non-activating, above full-screen apps, on every Space and display.
- Targets: `--at`, `--rect`, `--mouse`, `--window App[:title]`, `--element Label --app App` (Accessibility), `--peekaboo` / `--peekaboo-window` (Peekaboo 4.9.0 JSON).
- Lifetimes: `--duration`, `start` / `stop` (alias of `clear`), `--close-button`, `--until-click`, `--until-any-click`, `--follow`.
- Looks: `--shape bend|straight|zigzag`, `--style arrow|ring|box` (border-only marks), `--size S|M|L`, `--corners round|sharp`, ten colour presets and hex, automatic contrast, flared joint between sign and shaft, draw-on and pulse animations, Reduce Motion support.
- `front` and `--raise` bring the target's app and window to the front; `elements` lists what `--element` matches; `doctor` names the app that owns the permissions; `--say`; `--png`; `--dry-run`; `--json` everywhere; exit codes 0/2/3/4.
- The `big-arrow` skill for Claude Code and Codex, installed with `bigarrow install-skill`.
