# Skill test 2026-10-08: "show Franz where the Reload button in Google Chrome is"

Ticket T10 acceptance: a fresh agent with no context of this project gets the task and must use
the `big-arrow` skill and produce a correct `bigarrow point` command. Run as a Claude Code
general-purpose subagent on the planning Mac, with the skill symlinked into
`~/.claude/skills/big-arrow`. Because the human was working on that Mac, the prompt asked the
agent to add `--dry-run --json` to anything that would draw and not to raise or click anything.

## What the agent did

| # | Command | Exit | Output |
|---|---|---|---|
| 1 | `which bigarrow; pgrep -x "Google Chrome"` | 0 | bigarrow on PATH, Chrome running |
| 2 | `bigarrow elements --app "Google Chrome" --match "reload" --json` | 0 | two `AXButton` "Reload" (two Chrome windows), [78,80,34,34] and [84,80,34,34] |
| 3 | `bigarrow --help; bigarrow point --help` | 0 | options listed |
| 4 | `bigarrow point --element "Reload" --app "Google Chrome" --role button --text "Franz, this is Chrome's Reload button" --dry-run --json` | 0 | target rect [78,80,34,34], display 1, sign bottom-right |
| 5-6 | a read-only window-list helper | 0 | Ghostty in front, covering Chrome |

Skill used: `big-arrow`. The command it would run for real:

```bash
bigarrow point --element "Reload" --app "Google Chrome" --role button --raise \
  --text "Franz, this is Chrome's Reload button" --say --duration 12
```

Verdict: pass. It found the element by label instead of guessing coordinates, noticed that
Chrome was covered and added `--raise`, and wrote a full sentence on the sign.

## Bug it found

`--raise` ran before the `--dry-run` check, so a dry run could still bring an app to the front.
Fixed the same day: dry runs and `--png` renders never raise
(`Sources/bigarrow/PointRunner.swift`), with a screen test that the frontmost app is unchanged.
