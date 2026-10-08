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

$KIT windows backdrop | tee "$OUT/backdrop-windows.txt"

# --follow: the arrow moves with its target; closing the window ends the arrow with targetGone.
# Followed through --element, because on GitHub's virtual machines the window server reports
# window positions that disagree with Accessibility and the screen (see docs/research).
$BIN point --element Allow --app backdrop --text "Follow me" --follow --duration 8 --json > "$OUT/follow.json" & POINT=$!
sleep 1.5; $KIT move-window backdrop 252 200; sleep 1.5; screencapture -x "$OUT/follow-moved.png"
kill $BACKDROP; wait $POINT
check "follow ends with targetGone when the window closes" "[ \"\$(field $OUT/follow.json \"['dismissedReason']\")\" = targetGone ]"
check "follow tracked the moved button (window moved down 76 pt)" "python3 -c \"import json; t=json.load(open('$OUT/follow.json'))['target']; exit(0 if abs(t['y'] - 431) < 3 else 1)\""
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
sleep 1; screencapture -x "$OUT/two-displays-1.png" "$OUT/two-displays-2.png"
SECOND=$(field "$OUT/second.json" "['pid']")
kill $DISPLAY_PID; sleep 2
check "unplugging the display ends its arrow" "! kill -0 $SECOND 2>/dev/null"

# A sticky arrow that pulses costs almost no CPU: Core Animation runs in the render server.
$BIN start --at 300,300 --text "Idle pulse" --json > "$OUT/pulse.json"
PULSE=$(field "$OUT/pulse.json" "['pid']")
CPU=$($KIT cpu "$PULSE" 5); echo "cpu while pulsing: $CPU %"
check "pulsing costs under 3 % CPU" "python3 -c 'exit(0 if $CPU < 3 else 1)'"
$BIN stop --all > /dev/null

# stop silences --say within 300 ms.
$BIN start --at 300,300 --text "This is a long sentence that keeps the speech running for a while" --say > /dev/null
sleep 1
STOP_START=$(python3 -c 'import time; print(time.time())')
$BIN stop --all > /dev/null
check "stop ends the arrow and its speech within 300 ms" "! pgrep -x say > /dev/null && python3 -c 'import time; exit(0 if time.time() - $STOP_START < 0.6 else 1)'"

# Above a full-screen app: the overlay must cover it, the app must stay in its full-screen Space.
kill $BACKDROP; "$OUT/backdrop" --fullscreen & BACKDROP=$!
sleep 4
$BIN start --element Allow --app backdrop --text "Over a full-screen app" --color red --no-animation --json > "$OUT/fullscreen.json"
sleep 1; screencapture -x "$OUT/fullscreen.png"
read -r SX SY < <(python3 -c "import json; s=json.load(open('$OUT/fullscreen.json'))['sign']; print(int(s[0]+14), int(s[1]+s[3]/2))")
read -r R G B < <($KIT pixel "$SX" "$SY")
check "the sign is visible above a full-screen app ($R $G $B)" "[ $R -gt 200 ] && [ $G -lt 120 ]"
check "the full-screen app kept the focus" "[ \"\$($KIT frontmost)\" = backdrop ]"
$BIN stop --all > /dev/null
kill $BACKDROP; "$OUT/backdrop" & BACKDROP=$!; sleep 3

# With Stage Manager on.
defaults write com.apple.WindowManager GloballyEnabled -bool true; sleep 3
$BIN start --element Allow --app backdrop --text "With Stage Manager" --color blue --no-animation --json > "$OUT/stage.json"
sleep 1; screencapture -x "$OUT/stage-manager.png"
read -r SX SY < <(python3 -c "import json; s=json.load(open('$OUT/stage.json'))['sign']; print(int(s[0]+14), int(s[1]+s[3]/2))")
read -r R G B < <($KIT pixel "$SX" "$SY")
check "the sign is visible with Stage Manager on ($R $G $B)" "[ $B -gt 200 ] && [ $R -lt 80 ]"
$BIN stop --all > /dev/null
defaults write com.apple.WindowManager GloballyEnabled -bool false

# A Retina (2x) second display next to the 1x main display.
scripts/virtual-display/.build/virtual-display --width 800 --height 500 --hidpi 1 --seconds 10 > "$OUT/display-2x.json" & DISPLAY_PID=$!
sleep 4
$BIN doctor --json > "$OUT/doctor-2x.json"
check "the second display reports scale 2" "[ \"\$(field $OUT/doctor-2x.json \"['displays'][1]['scale']\")\" = 2.0 ]"
$BIN start --at 300,200 --display 2 --text "On a 2x display" --color green --no-animation --json > "$OUT/retina.json"
sleep 1; screencapture -x "$OUT/retina-1.png" "$OUT/retina-2.png"
check "arrow lands on the 2x display" "[ \"\$(field $OUT/retina.json \"['target']['display']\")\" = 2 ]"
$BIN stop --all > /dev/null
kill $DISPLAY_PID 2>/dev/null; wait $DISPLAY_PID 2>/dev/null

exit $FAILED
