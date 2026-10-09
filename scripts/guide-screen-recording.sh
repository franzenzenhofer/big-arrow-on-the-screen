#!/bin/bash
# Screenshots for docs/guides/allow-screen-recording: System Settings opened by deep link, one real
# bigarrow arrow per step, captured at Retina resolution around the window and the sign. Run on
# the test Mac (Arthur), never on a desk in use. It only points: no switch is ever clicked, no
# permission granted or revoked.
# Nothing personal: for steps 1 and 2 the window's sidebar (its first row is the Apple Account
# name) sits off the left edge of the screen; for step 3 the sidebar is scrolled past that row.
# Other apps, the Dock and desktop widgets are hidden for the shots; the Dock, the widgets and
# the window's frame are restored on exit.
# Usage: scripts/guide-screen-recording.sh <out-dir>
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
APP="System Settings"
WORK=$(mktemp -d)
mkdir -p "$OUT"
DOCK_AUTOHIDE=$(defaults read com.apple.dock autohide 2>/dev/null || echo 0)
WIDGETS_HIDDEN=$(defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null || echo 0)
FRAME=""
# frame: the window's x,y,w,h (read again until System Settings answers with all four).
frame() {
  local value
  for _ in 1 2 3 4 5; do
    value=$(osascript -e "tell application \"System Events\" to tell process \"$APP\" to get {position, size} of window 1" | tr -d ' ')
    [ "$(tr -cd ',' <<< "$value" | wc -c)" -eq 3 ] && { echo "$value"; return; }
    sleep 0.5
  done
  echo "could not read the System Settings window frame" >&2; exit 1
}
# place <x> <y> <w> <h>: size first, or macOS moves the window to keep the old size on screen.
place() {
  osascript -e "tell application \"System Events\" to tell process \"$APP\" to set size of window 1 to {$3, $4}" \
    -e "tell application \"System Events\" to tell process \"$APP\" to set position of window 1 to {$1, $2}" > /dev/null
  sleep 0.8
}
cleanup() {
  $BIN stop --all > /dev/null 2>&1
  [ -n "$FRAME" ] && place ${FRAME//,/ }
  defaults write com.apple.dock autohide -int "$DOCK_AUTOHIDE"; killall Dock
  defaults write com.apple.WindowManager StandardHideWidgets -int "$WIDGETS_HIDDEN"
}
trap cleanup EXIT
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.WindowManager StandardHideWidgets -bool true

# The agent's first command: the exact pane, by deep link.
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
sleep 3
title=$(osascript -e "tell application \"System Events\" to tell process \"$APP\" to get name of window 1")
[ "$title" = "Screen & System Audio Recording" ] || { echo "deep link opened '$title'" >&2; exit 1; }
osascript -e "tell application \"System Events\" to set visible of every process whose visible is true and name is not \"$APP\" to false"
FRAME=$(frame)

# step <name> <bigarrow start options...>: one arrow, one shot of the window and the sign, 32 pt
# around them, clipped to the screen and never the menu bar.
step() {
  local name="$1" result region; shift
  result=$($BIN start --app "$APP" --text "$@" --no-animation --json) || { echo "step $name failed" >&2; exit 1; }
  sleep 1.2
  region=$(python3 - "$result" "$(frame)" <<'PY'
import json, sys
sx, sy, sw, sh = json.loads(sys.argv[1])["sign"]
x, y, w, h = (float(v) for v in sys.argv[2].split(","))
left = max(min(x, sx) - 32, 0)
top = max(min(y, sy) - 32, 34)
right = min(max(x + w, sx + sw) + 32, 1470)
bottom = min(max(y + h, sy + sh) + 32, 956)
print(f"{left:.0f},{top:.0f},{right - left:.0f},{bottom - top:.0f}")
PY
)
  screencapture -x -R "$region" "$WORK/$name.png"
  $BIN stop --all > /dev/null
  # 256 colours, then smaller until the file is under 700 KB.
  python3 - "$WORK/$name.png" "$OUT/$name.png" <<'PY'
import os, sys
from PIL import Image
image = Image.open(sys.argv[1]).convert("RGB")
while True:
    image.quantize(256, method=Image.Quantize.MEDIANCUT, kmeans=2).save(sys.argv[2], optimize=True)
    if os.path.getsize(sys.argv[2]) < 700_000:
        break
    image = image.resize((int(image.width * 0.85), int(image.height * 0.85)), Image.LANCZOS)
PY
  echo "$name: $region"
}

place -250 150 754 625
step 1-open-pane "You are in the right place: Screen & System Audio Recording" \
  --element "Screen & System Audio Recording" --role statictext --from right
step 2-switch-on "Chrome's switch: on means Chrome may record your screen" \
  --element "Google Chrome_Toggle" --from right
# The window ends just below the list, so the arrow comes up from below without crossing the
# "System Audio Recording Only" heading.
place 60 40 754 580
osascript -e "tell application \"System Events\" to tell process \"$APP\" to set value of scroll bar 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1 to 1.0" > /dev/null
step 3-add-app "Chrome missing? Click +" --element Add --from bottom
ls -la "$OUT"
