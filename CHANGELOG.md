# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
