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

$AB --headed --profile "$WORK/profile" --args "--hide-crash-restore-bubble,--no-first-run,--no-default-browser-check" \
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
    comments: r(comments[0]), vote: r(votes[11] || votes[votes.length - 1]) });
})()' | tail -1)
echo "$RECTS"
rect() { python3 -c "import json,sys; v=json.loads(sys.argv[1]); v=json.loads(v) if isinstance(v,str) else v; print(v[sys.argv[2]])" "$RECTS" "$1"; }

$BIN start --rect "$(rect logo)" --text "Same design since 2007. Still works." --color orange --corners sharp --from bottom --size S --no-animation > /dev/null
$BIN start --rect "$(rect past)" --text "Today's thread, already argued in 2014" --color teal --shape straight --from bottom-right --size S --no-animation > /dev/null
$BIN start --rect "$(rect comments)" --text "The actual article is in here" --color purple --shape zigzag --from right --size S --no-animation > /dev/null
$BIN start --rect "$(rect vote)" --text "Finally, an arrow bigger than this one" --color red --from right --size S --no-animation > /dev/null
# By label through Accessibility, which reaches web content in Chromium browsers.
$BIN start --element login --app "$BROWSER" --text "Agents can't do this part. That's the point." --color green --from bottom-left --size S --no-animation --json
sleep 2
screencapture -x "$OUT"
echo "wrote $OUT"
