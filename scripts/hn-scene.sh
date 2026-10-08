#!/bin/zsh
# README hero: the Hacker News front page in a visible browser window with arrows that make a
# point. Run on the test Mac (Arthur) through scripts/arthur-gui.sh, never on a desk in use.
# A fresh browser profile keeps any signed-in account out of the picture.
# Usage: scripts/hn-scene.sh <out.png>
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
AB=/opt/homebrew/bin/agent-browser
WORK=$(mktemp -d)
swiftc -O scripts/testkit.swift -o "$WORK/testkit" || exit 1
KIT="$WORK/testkit"
cleanup() { $BIN stop --all >/dev/null 2>&1; $AB close >/dev/null 2>&1; }
trap cleanup EXIT

$AB --headed --profile "$WORK/profile" --args "--hide-crash-restore-bubble,--no-first-run,--no-default-browser-check,--force-renderer-accessibility" \
  open https://news.ycombinator.com > /dev/null
sleep 3
$KIT move-window frontmost 15 35; $KIT resize-window frontmost 1440 860; sleep 1.5
BROWSER=$($KIT frontmost)
RECTS=$($AB eval '(() => {
  const top = window.screenY + (window.outerHeight - window.innerHeight), left = window.screenX;
  const r = e => { const b = e.getBoundingClientRect();
    return [Math.round(left + b.x), Math.round(top + b.y), Math.max(1, Math.round(b.width)), Math.max(1, Math.round(b.height))].join(","); };
  const link = t => [...document.querySelectorAll("a")].find(a => a.textContent.trim() === t);
  const comments = [...document.querySelectorAll(".subline a")].filter(a => /comment/.test(a.textContent));
  const votes = [...document.querySelectorAll(".votearrow")];
  return JSON.stringify({ logo: r(document.querySelector("img[src*=y18]")), past: r(link("past")),
    comments: r(comments[0]), vote: r(votes[11] || votes[votes.length - 1]), login: r(link("login")) });
})()' | tail -1)
echo "$RECTS"
rect() { python3 -c "import json,sys; v=json.loads(sys.argv[1]); v=json.loads(v) if isinstance(v,str) else v; print(v[sys.argv[2]])" "$RECTS" "$1"; }

# The most constrained arrow first (far right, longest sign); later arrows keep clear of earlier ones.
# Every arrow must land exactly on its element: the target each arrow reports is compared with
# the element's rectangle from the page, and the scene fails if one is off by more than 2 pt.
check_target() {
  python3 - "$1" "$2" <<'PY' || { echo "arrow '$3' missed its element" >&2; exit 1; }
import json, sys
reported = json.loads(sys.argv[1])["target"]["rect"]
expected = [float(v) for v in sys.argv[2].split(",")]
sys.exit(0 if all(abs(a - b) <= 2 for a, b in zip(reported, expected)) else 1)
PY
}
# Independent proof that page coordinates are screen coordinates: every page rect must match the
# frame of an Accessibility element at the same place.
$BIN elements --app "$BROWSER" --json > "$WORK/ax.json"
check_on_screen() {
  python3 - "$WORK/ax.json" "$1" <<'PY' || { echo "page rect '$2' matches no Accessibility element" >&2; exit 1; }
import json, sys
frames = [n["frame"] for n in json.load(open(sys.argv[1])) if n.get("frame")]
x, y, w, h = (float(v) for v in sys.argv[2].split(","))
sys.exit(0 if any(abs(f[0][0] - x) <= 2 and abs(f[0][1] - y) <= 2 and abs(f[1][0] - w) <= 2 and abs(f[1][1] - h) <= 2 for f in frames) else 1)
PY
}
point() {
  local name="$1"; shift
  local result
  check_on_screen "$(rect "$name")" "$name"
  result=$($BIN start "$@" --size S --no-animation --json) || exit 1
  check_target "$result" "$(rect "$name")" "$name"
  echo "on target: $name"
}
# By label through Accessibility: Chrome exposes web pages to it when started with
# --force-renderer-accessibility (or while VoiceOver runs).
point login --element login --role link --app "$BROWSER" --text "Not a lurker? Click login." --color green
point logo --rect "$(rect logo)" --text "Same design since 2007. Still works." --color orange --corners sharp
point comments --rect "$(rect comments)" --text "The actual article is in here" --color purple --shape zigzag
point past --rect "$(rect past)" --text "Today's thread, already argued in 2014" --color teal --shape straight
point vote --rect "$(rect vote)" --text "Finally, an arrow bigger than this one" --color red
sleep 2
screencapture -x "$OUT"
echo "wrote $OUT"
