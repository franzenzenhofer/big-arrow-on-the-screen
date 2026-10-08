#!/bin/bash
# Behaviour checks that click, move windows, raise apps, speak and add displays. Run only on a
# disposable machine (the CI runner), never on a Mac somebody is working on.
# Usage: scripts/behaviour-check.sh <out-dir>; exits non-zero when any check fails.
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
mkdir -p "$OUT"
FAILED=0
check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; FAILED=1; fi; }
field() { python3 -c "import json,sys; d=json.load(open('$1')); print(eval('d' + sys.argv[1]))" "$2"; }

swiftc -O scripts/testkit.swift -o "$OUT/testkit" && swiftc -O scripts/backdrop.swift -o "$OUT/backdrop"
scripts/virtual-display/build.sh > /dev/null
KIT="$OUT/testkit"
"$OUT/backdrop" & BACKDROP=$!
trap 'kill $BACKDROP 2>/dev/null; $BIN stop --all >/dev/null 2>&1' EXIT
sleep 2

# The close button: a real click on the X ends the arrow and leaves the focus where it was.
FRONT=$($KIT frontmost)
$BIN start --at 300,300 --text "Close me" --close-button --json > "$OUT/close.json"
PID=$(field "$OUT/close.json" "['pid']")
read -r X Y < <(python3 -c "import json; s=json.load(open('$OUT/close.json'))['sign']; print(int(s[0]+s[2]-8), int(s[1]+8))")
sleep 1; $KIT click "$X" "$Y"; sleep 1
check "close button ends the arrow" "! kill -0 $PID 2>/dev/null"
check "clicking the X keeps the focus" "[ \"\$($KIT frontmost)\" = \"$FRONT\" ]"

# --until-click: a click on the target ends it with dismissedReason clicked.
$BIN point --at 400,500 --text "Click the target" --until-click --json > "$OUT/until-click.json" & POINT=$!
sleep 1.5; $KIT click 400 500; wait $POINT
check "until-click reports clicked" "[ \"\$(field $OUT/until-click.json \"['dismissedReason']\")\" = clicked ]"

# --follow: the arrow moves with the window; closing it ends the arrow with targetGone.
$BIN point --window backdrop --anchor title --text "Follow me" --follow --duration 8 --json > "$OUT/follow.json" & POINT=$!
sleep 1.5; $KIT move-window backdrop 100 200; sleep 1.5; screencapture -x "$OUT/follow-moved.png"
kill $BACKDROP; wait $POINT
check "follow ends with targetGone when the window closes" "[ \"\$(field $OUT/follow.json \"['dismissedReason']\")\" = targetGone ]"
check "follow tracked the moved window" "python3 -c \"import json; t=json.load(open('$OUT/follow.json'))['target']; exit(0 if abs(t['y'] - 214) < 3 else 1)\""
"$OUT/backdrop" & BACKDROP=$!
sleep 2

# --raise brings the target app to the front before pointing.
$KIT activate Finder
$BIN point --window backdrop --raise --text "Raised" --duration 1 --json > "$OUT/raise.json"
check "raise brought the target app to the front" "[ \"\$($KIT frontmost)\" = backdrop ]"

# --say speaks and still exits 0.
check "say works" "$BIN point --at 300,300 --text 'Hello from bigarrow' --say --duration 2 > /dev/null"

# A second display: point at it, then unplug it while the arrow is up.
scripts/virtual-display/.build/virtual-display --width 1280 --height 800 --hidpi 0 --seconds 12 > "$OUT/display.json" & DISPLAY_PID=$!
sleep 4
$BIN doctor --json > "$OUT/doctor-two-displays.json"
check "doctor sees two displays" "[ \"\$(field $OUT/doctor-two-displays.json \"['displays'].__len__()\")\" = 2 ]"
$BIN start --at 200,200 --display 2 --text "On the second display" --color blue --json > "$OUT/second.json"
check "arrow lands on display 2" "[ \"\$(field $OUT/second.json \"['target']['display']\")\" = 2 ]"
screencapture -x "$OUT/two-displays.png"
SECOND=$(field "$OUT/second.json" "['pid']")
kill $DISPLAY_PID; sleep 2
check "unplugging the display ends its arrow" "! kill -0 $SECOND 2>/dev/null"

exit $FAILED
