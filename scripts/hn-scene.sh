#!/bin/zsh
# README hero: the Hacker News front page in a visible browser window with arrows that make a
# point. Run on the test Mac (Arthur) through scripts/arthur-gui.sh, never on a desk in use.
# Usage: scripts/hn-scene.sh <out.png> [x,y of a notification banner to dismiss first]
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
AB=/opt/homebrew/bin/agent-browser
WORK=$(mktemp -d)
swiftc -O scripts/testkit.swift -o "$WORK/testkit" || exit 1
KIT="$WORK/testkit"
cleanup() { $BIN stop --all >/dev/null 2>&1; $AB close >/dev/null 2>&1; }
trap cleanup EXIT

if [ -n "${2:-}" ]; then
  $KIT click "${2%,*}" "${2#*,}"; sleep 2; pkill -x "System Settings"; sleep 1
fi
$AB --headed open https://news.ycombinator.com > /dev/null
sleep 3
BROWSER=$($KIT frontmost)
echo "browser app: $BROWSER"
$KIT move-window "$BROWSER" 40 60; $KIT resize-window "$BROWSER" 1390 780; sleep 1.5
# Element rects in global top-left screen points: window origin plus the browser chrome height.
RECTS=$($AB eval '(() => {
  const top = window.screenY + (window.outerHeight - window.innerHeight), left = window.screenX;
  const r = e => { const b = e.getBoundingClientRect();
    return [Math.round(left + b.x), Math.round(top + b.y), Math.max(1, Math.round(b.width)), Math.max(1, Math.round(b.height))].join(","); };
  const link = t => [...document.querySelectorAll("a")].find(a => a.textContent.trim() === t);
  const comments = [...document.querySelectorAll(".subline a")].find(a => /comment/.test(a.textContent));
  return JSON.stringify({ vote: r(document.querySelector(".votearrow")), comments: r(comments),
    logo: r(document.querySelector("img[src*=y18]")), fresh: r(link("new")) });
})()' | tail -1)
echo "$RECTS"
rect() { python3 -c "import json,sys; v=json.loads(sys.argv[1]); v=json.loads(v) if isinstance(v,str) else v; print(v[sys.argv[2]])" "$RECTS" "$1"; }

$BIN start --rect "$(rect vote)" --text "Finally, an arrow bigger than this one" --color red --from bottom-right --no-animation > /dev/null
$BIN start --rect "$(rect comments)" --text "The actual article is in here" --color purple --shape zigzag --from bottom-right --no-animation > /dev/null
$BIN start --rect "$(rect logo)" --text "Same design since 2007. Still works." --color orange --corners sharp --from bottom --no-animation > /dev/null
$BIN start --rect "$(rect fresh)" --text "Where Show HNs wait for their first upvote" --color blue --shape straight --from bottom --no-animation > /dev/null
# By label through Accessibility, which now reaches web content in Chromium browsers.
$BIN start --element login --app "$BROWSER" --text "Agents can't do this part. That's the point." --color green --from bottom-left --no-animation --json | tee "$WORK/login.json"
sleep 2
screencapture -x "$OUT"
echo "wrote $OUT"
