#!/bin/zsh
# README hero: a Hacker News front page with five arrows that make a point. Run on the test Mac
# (Arthur) through scripts/arthur-gui.sh, never on a desk in use.
# - The page is the front page of 2014-06-10: every visible headline is tech, nothing political,
#   criminal or sad, and it fits "already argued in 2014".
# - Chrome runs as an --app window (no tabs, no address bar) with a fresh temporary profile.
# - The scene lives on a temporary 4400x2600 virtual display (scripts/virtual-display), with the
#   page zoomed to 200 %: big enough for the page to fill the shot and for every sign to sit
#   outside the headlines. Arrows enter from free space above, left or right of their target;
#   point targets (--at) instead of boxes keep the header text and the headlines uncovered.
# Usage: scripts/hn-scene.sh <out.png>
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
URL="https://news.ycombinator.com/front?day=2014-06-10"
WORK=$(mktemp -d)
scripts/virtual-display/build.sh > /dev/null || exit 1
CHROME_PID=""; DISPLAY_PID=""
cleanup() {
  $BIN stop --all > /dev/null 2>&1
  [ -n "$CHROME_PID" ] && kill "$CHROME_PID" 2>/dev/null
  [ -n "$DISPLAY_PID" ] && kill "$DISPLAY_PID" 2>/dev/null
}
trap cleanup EXIT

scripts/virtual-display/.build/virtual-display --width 4400 --height 2600 --hidpi 0 --seconds 300 \
  > "$WORK/display.json" 2> "$WORK/display.err" & DISPLAY_PID=$!
for _ in {1..30}; do [ -s "$WORK/display.json" ] && break; sleep 0.5; done
[ -s "$WORK/display.json" ] || { cat "$WORK/display.err" >&2; exit 1; }
read DX DY <<< "$(python3 -c 'import json, sys; f = json.load(open(sys.argv[1]))["frame"]; print(f["x"], f["y"])' "$WORK/display.json")"

open -na "Google Chrome" --args --user-data-dir="$WORK/chrome" --app="$URL" --force-renderer-accessibility \
  --no-first-run --no-default-browser-check --disable-search-engine-choice-screen --hide-crash-restore-bubble
sleep 5
CHROME_PID=$(pgrep -f "MacOS/Google Chrome --user-data-dir=$WORK/chrome" | head -1)
[ -n "$CHROME_PID" ] || { echo "Chrome did not start" >&2; exit 1; }
for _ in {1..30}; do
  [ "$(osascript -e "tell application \"System Events\" to count windows of (first process whose unix id is $CHROME_PID)")" -gt 0 ] && break
  sleep 0.5
done
# Another Chrome may be running: this one is addressed by its pid. Move first, then size, or the
# window is clamped to the built-in display.
osascript > /dev/null <<AS
tell application "System Events" to tell (first process whose unix id is $CHROME_PID)
  set frontmost to true
  set position of window 1 to {$((DX + 1130)), $((DY + 410))}
  set size of window 1 to {2400, 1170}
  repeat 5 times
    click menu item "Zoom In" of menu "View" of menu bar 1
    delay 0.4
  end repeat
end tell
AS
sleep 1.5

# Targets from Accessibility, in global top-left points. The headlines are printed for review.
$BIN elements --app "Google Chrome" --json > "$WORK/ax.json" || exit 1
TARGETS=$(python3 - "$WORK/ax.json" <<'PY'
import json, re, sys
# Accessibility reports most page elements twice; keep one per role, label and frame.
nodes = list({(n["role"], n.get("title"), str(n["frame"])): n for n in json.load(open(sys.argv[1])) if n.get("frame")}.values())
links = [n for n in nodes if n["role"] == "AXLink"]
label = lambda n: (n.get("title") or n.get("label") or "").replace("\xa0", " ")
frame = lambda n: [v for pair in n["frame"] for v in pair]
logo = next(n for n in links if label(n).startswith("To get missing image"))
past = next(n for n in links if label(n) == "past")
comments = next(n for n in links if re.fullmatch(r"\d+ comments", label(n)))
title = next(n for n in links if label(n) == "Netflix responds to Verizon")
# The vote arrows sit in the narrow cells left of each headline; the 12th is row 12.
votes = sorted((n for n in nodes if n["role"] == "AXCell" and abs(n["frame"][0][0] - (title["frame"][0][0] - 28)) <= 3
                and n["frame"][1][0] < 40), key=lambda n: n["frame"][0][1])
x, y, w, h = frame(logo); print(f"logo={x + 2:.0f},{y + h / 2:.0f}")
x, y, w, h = frame(past); print(f"past={x + w / 2:.0f},{y + 2:.0f}")
x, y, w, h = frame(comments); print(f"comments={x + w - 3:.0f},{y + h / 2:.0f}")
x, y, w, h = frame(votes[11]); print(f"vote={x + 7:.0f},{y + 11:.0f}")
x, y, w, h = frame(title)
for n in links:
    if abs(n["frame"][0][0] - x) <= 2 and n["frame"][1][1] >= 30:
        print(f"# headline: {label(n)}", file=sys.stderr)
PY
) || exit 1
typeset -A AT
for line in ${(f)TARGETS}; do AT[${line%%=*}]=${line#*=}; done

# Every arrow must land exactly where it was sent: the target it reports is compared with the
# requested point (or, for login, with the link's frame from Accessibility).
point() {
  local name="$1"; shift
  $BIN start "$@" --size L --shape straight --no-animation --no-raise --json >> "$WORK/arrows.json" || exit 1
  echo "drawn: $name"
}
point login --element login --role link --app "Google Chrome" --text "Not a lurker? Click login." --color green --from top
point comments --at "$AT[comments]" --text "The actual article is in here" --color purple --from right
point past --at "$AT[past]" --text "Today's thread, already argued in 2014" --color teal --from top
point vote --at "$AT[vote]" --text "Finally, an arrow bigger than this one" --color red --from left
point logo --at "$AT[logo]" --text "Same design since 2007. Still works." --color orange --corners sharp --from left
python3 - "$WORK/arrows.json" "$AT[comments]" "$AT[past]" "$AT[vote]" "$AT[logo]" <<'PY' || { echo "an arrow missed its target" >&2; exit 1; }
import json, sys
arrows = [json.loads(line) for line in open(sys.argv[1])]
for arrow, wanted in zip(arrows[1:], sys.argv[2:]):
    x, y = (float(v) for v in wanted.split(","))
    target = arrow["target"]
    assert abs(target["x"] - x) <= 1 and abs(target["y"] - y) <= 1, (target, wanted)
assert arrows[0]["target"]["source"] == "element", arrows[0]["target"]
PY
sleep 2

# The window and every sign, 32 pt around them, below the virtual display's menu bar. The
# display is 1x and the page is zoomed 2x, so the shot is halved to keep its text sharp.
REGION=$(python3 - "$WORK/arrows.json" "$DX" "$DY" <<'PY'
import json, sys
dx, dy = float(sys.argv[2]), float(sys.argv[3])
rects = [(dx + 1130, dy + 410, dx + 3530, dy + 1580)]
for line in open(sys.argv[1]):
    x, y, w, h = json.loads(line)["sign"]
    rects.append((x, y, x + w, y + h))
left, top = min(r[0] for r in rects) - 32, max(min(r[1] for r in rects) - 32, dy + 40)
right, bottom = max(r[2] for r in rects) + 32, max(r[3] for r in rects) + 32
print(f"{left:.0f},{top:.0f},{right - left:.0f},{bottom - top:.0f}")
PY
)
screencapture -x -R "$REGION" "$WORK/shot.png" || exit 1
python3 - "$WORK/shot.png" "$OUT" <<'PY'
import sys
from PIL import Image
image = Image.open(sys.argv[1]).convert("RGB")
image = image.resize((image.width // 2, image.height // 2), Image.LANCZOS)
image.quantize(256, method=Image.Quantize.MEDIANCUT, kmeans=2).save(sys.argv[2], optimize=True)
PY
echo "wrote $OUT ($REGION)"
