#!/bin/bash
# Real apps, real use cases for the README: System Settings, Keynote, TextEdit, Chrome and Finder
# staged with neutral content, one real bigarrow command each, captured at Retina resolution
# around the app and the arrow. Run on the test Mac (Arthur), never on a desk in use.
# Other apps are hidden, the Dock and desktop widgets too (restored on exit); demo files live in
# a temporary folder and Chrome gets a fresh temporary profile, so nothing personal is on screen.
# Usage: scripts/real-scenes.sh <out-dir> [scene ...]   (scenes: settings keynote print chrome finder)
set -uo pipefail
OUT="$1"; shift
SCENES="${*:-settings keynote print chrome finder}"
BIN=.build/release/bigarrow
# Resolved (/private/tmp/...) so it compares equal to the paths apps report for files in it.
WORK=$(cd "$(mktemp -d /tmp/real-scenes.XXXXXX)" && pwd -P)
mkdir -p "$OUT"
swiftc -O scripts/testkit.swift -o "$WORK/testkit" || exit 1
KIT="$WORK/testkit"
DOCK_AUTOHIDE=$(defaults read com.apple.dock autohide 2>/dev/null || echo 0)
WIDGETS_HIDDEN=$(defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null || echo 0)
# What the scenes opened; each close_* closes only that, so a failed scene leaves nothing behind
# and nothing of the human's (other decks, documents, Chrome windows) is ever touched.
CHROME_PID=""; KEYNOTE_DOC=""; TEXTEDIT_DOC=""; PRINT_SHEET=""; FINDER_FOLDER=""
close_chrome() { [ -n "$CHROME_PID" ] && kill "$CHROME_PID" 2>/dev/null; CHROME_PID=""; }
close_keynote() {
  [ -n "$KEYNOTE_DOC" ] && osascript -e "tell application \"Keynote Creator Studio\" to close (every document whose id is \"$KEYNOTE_DOC\") saving no" > /dev/null
  KEYNOTE_DOC=""
}
close_print_sheet() {
  [ -n "$PRINT_SHEET" ] && osascript -e 'tell application "TextEdit" to activate' -e 'tell application "System Events" to key code 53' -e 'delay 1' > /dev/null
  PRINT_SHEET=""
}
close_textedit() {
  close_print_sheet
  [ -n "$TEXTEDIT_DOC" ] && osascript -e "tell application \"TextEdit\" to close (every document whose path is \"$TEXTEDIT_DOC\") saving no" > /dev/null
  TEXTEDIT_DOC=""
}
close_finder() {
  [ -n "$FINDER_FOLDER" ] && osascript - "$FINDER_FOLDER/" > /dev/null <<'AS'
on run {wanted}
  tell application "Finder"
    repeat with i from (count Finder windows) to 1 by -1
      if POSIX path of ((target of Finder window i) as alias) is wanted then close Finder window i
    end repeat
  end tell
end run
AS
  FINDER_FOLDER=""
}
cleanup() {
  $BIN stop --all >/dev/null 2>&1
  close_chrome; close_keynote; close_textedit; close_finder
  defaults write com.apple.dock autohide -int "$DOCK_AUTOHIDE"; killall Dock
  defaults write com.apple.WindowManager StandardHideWidgets -int "$WIDGETS_HIDDEN"
}
trap cleanup EXIT
defaults write com.apple.dock autohide -bool true; killall Dock
defaults write com.apple.WindowManager StandardHideWidgets -bool true

hide_others() {
  osascript -e "tell application \"System Events\" to set visible of every process whose visible is true and name is not \"$1\" to false"
}
# place <process> <x> <y> [w h]: moves (and sizes) the process's front window, top-left points.
place() {
  osascript -e "tell application \"System Events\" to tell process \"$1\" to set position of window 1 to {$2, $3}" > /dev/null
  [ $# -ge 5 ] && osascript -e "tell application \"System Events\" to tell process \"$1\" to set size of window 1 to {$4, $5}" > /dev/null
  sleep 0.5
}
# click_element <app> <label>: a real click in the middle of the first element with that label.
click_element() {
  local at
  at=$($BIN elements --app "$1" --match "$2" --json | python3 -c 'import json, sys
f = json.load(sys.stdin)[0]["frame"]
print(round(f[0][0] + f[1][0] / 2), round(f[0][1] + f[1][1] / 2))')
  $KIT click $at
}
frame() {
  osascript -e "tell application \"System Events\" to tell process \"$1\" to get {position, size} of window 1" | tr -d ' '
}
# arrow <command...>: runs one bigarrow start with --json and keeps its sign for the crop.
arrow() {
  "$@" --no-animation --json >> "$WORK/arrows.json" || { echo "arrow failed: $*" >&2; exit 1; }
}
# shoot <name> <window x,y,w,h>: captures the window plus every sign, 32 pt around them, never
# the menu bar, clipped to the test Mac's 1470x956 point display.
shoot() {
  sleep 1.2
  local region
  region=$(python3 - "$2" "$WORK/arrows.json" <<'PY'
import json, sys
x, y, w, h = (float(v) for v in sys.argv[1].split(","))
rects = [(x, y, x + w, y + h)]
for line in open(sys.argv[2]):
    sx, sy, sw, sh = json.loads(line)["sign"]
    rects.append((sx, sy, sx + sw, sy + sh))
pad = 32
left = max(min(r[0] for r in rects) - pad, 0)
top = max(min(r[1] for r in rects) - pad, 34)
right = min(max(r[2] for r in rects) + pad, 1470)
bottom = min(max(r[3] for r in rects) + pad, 956)
print(f"{left:.0f},{top:.0f},{right - left:.0f},{bottom - top:.0f}")
PY
)
  screencapture -x -R "$region" "$OUT/$1.png"
  echo "$1: $region"
  $BIN stop --all > /dev/null
  : > "$WORK/arrows.json"
}

scene_settings() {
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"; sleep 2.5
  # The sidebar (it shows the Apple Account name) sits off the left edge of the screen.
  hide_others "System Settings"; place "System Settings" -250 160
  arrow $BIN start --element Terminal_Toggle --app "System Settings" \
    --text "Franz, switch this on: Terminal may control your Mac" --from right
  shoot settings "$(frame "System Settings")"
}

# A neutral three-slide deck. Keynote shows a "What's New" window once after an update: run
# the scene again after dismissing it. Other open decks are left alone but must not be in view.
scene_keynote() {
  KEYNOTE_DOC=$(osascript <<'AS'
tell application "Keynote Creator Studio"
  activate
  set d to make new document with properties {document theme:theme "Basic White"}
  tell d
    set object text of default title item of slide 1 to "Garden Club"
    set object text of default body item of slide 1 to "Spring meeting"
    set s2 to make new slide with properties {base slide:master slide "Title & Bullets"}
    set object text of default title item of s2 to "What we plant this year"
    set object text of default body item of s2 to "Tomatoes" & return & "Beans" & return & "Sunflowers"
    set s3 to make new slide with properties {base slide:master slide "Title & Bullets"}
    set object text of default title item of s3 to "Who waters when"
    set object text of default body item of s3 to "Mondays: Anna" & return & "Wednesdays: Ben" & return & "Saturdays: everyone"
    set current slide to s2
  end tell
  return id of d
end tell
AS
) && [ -n "$KEYNOTE_DOC" ] || { echo "keynote: could not create the demo deck" >&2; exit 1; }
  sleep 1.5
  hide_others Keynote; place Keynote 20 130 900 740
  local win; win=$(frame Keynote)
  # Open the Animate inspector so step 2 has its button on screen.
  click_element Keynote Animate
  sleep 1
  arrow $BIN start --element Animate --app Keynote --role radiobutton --text "1. Click Animate" --from right
  arrow $BIN start --element "Add an Effect" --app Keynote --text "2. Add an Effect" --from right
  shoot keynote "$win"
  close_keynote
}

scene_print() {
  printf 'Shopping list\n\nBread\nMilk\nApples\nCoffee\nBirthday card for Grandpa\n' > "$WORK/Shopping list.txt"
  TEXTEDIT_DOC="$WORK/Shopping list.txt"
  open -a TextEdit "$TEXTEDIT_DOC"; sleep 2
  osascript -e 'tell application "System Events" to tell process "TextEdit" to set value of attribute "AXMinimized" of (every window whose name is not "Shopping list.txt") to true' > /dev/null 2>&1
  hide_others TextEdit; place TextEdit 400 60 760 560
  local win; win=$(frame TextEdit)
  PRINT_SHEET=1
  osascript -e 'tell application "TextEdit" to activate' -e 'tell application "System Events" to keystroke "p" using command down'
  sleep 2.5
  arrow $BIN start --element PDF --role button --app TextEdit --text "Mom, click PDF, then Save as PDF" --from bottom
  shoot print "$win"
  close_textedit
}

# A fresh Chrome profile in the temporary folder: no account, avatar, bookmarks or history.
# Three windows, 14 Wikipedia tabs; the arrow raises the middle window and selects the tab.
scene_chrome() {
  local profile="$WORK/chrome" wiki=https://en.wikipedia.org/wiki
  local flags=(--user-data-dir="$profile" --no-first-run --no-default-browser-check
    --disable-search-engine-choice-screen --hide-crash-restore-bubble --new-window)
  open -na "Google Chrome" --args "${flags[@]}" $wiki/Banana $wiki/Bicycle $wiki/Lighthouse $wiki/Tea $wiki/Volcano; sleep 5
  CHROME_PID=$(pgrep -f "MacOS/Google Chrome --user-data-dir=$profile" | head -1)
  [ -n "$CHROME_PID" ] || { echo "chrome: the temporary Chrome did not start" >&2; exit 1; }
  open -na "Google Chrome" --args "${flags[@]}" $wiki/Penguin $wiki/Rainbow $wiki/Sourdough $wiki/Origami $wiki/Kite; sleep 4
  open -na "Google Chrome" --args "${flags[@]}" $wiki/Tomato $wiki/Bread $wiki/Waffle $wiki/Pancake; sleep 5
  # Another Chrome may be running: everything is addressed by this instance's pid.
  osascript -e "tell application \"System Events\" to set visible of every process whose visible is true and unix id is not $CHROME_PID to false"
  osascript > /dev/null <<AS
tell application "System Events" to tell (first process whose unix id is $CHROME_PID)
  set position of window "Banana - Wikipedia - Google Chrome" to {420, 390}
  set size of window "Banana - Wikipedia - Google Chrome" to {980, 520}
  set position of window "Penguin - Wikipedia - Google Chrome" to {240, 360}
  set size of window "Penguin - Wikipedia - Google Chrome" to {980, 520}
  set position of window "Tomato - Wikipedia - Google Chrome" to {60, 330}
  set size of window "Tomato - Wikipedia - Google Chrome" to {980, 520}
end tell
AS
  sleep 1
  arrow $BIN start --app "Google Chrome:Sourdough" --element "Sourdough - Wikipedia" --role radiobutton \
    --text "It's this tab, not the other 13" --from top
  shoot chrome "60,330,1340,580"
  close_chrome
}

# A demo folder in the temporary folder (no home folder name anywhere), sidebar hidden. On
# macOS 27 the old gear is three dots; the look-alike pair is the icon view and Group buttons.
scene_finder() {
  local folder="$WORK/Family Recipes" name
  mkdir -p "$folder/Cakes" "$folder/Soups" "$folder/Salads"
  for name in "Apple pie" "Grandma's goulash" "Pancakes" "Lemonade" "Shopping list"; do
    echo "$name" > "$folder/$name.txt"
  done
  FINDER_FOLDER="$folder"
  open "$folder"; sleep 2
  osascript -e 'tell application "Finder" to set sidebar width of front window to 0' \
    -e 'tell application "Finder" to set current view of front window to icon view' \
    -e 'tell application "Finder" to set bounds of front window to {300, 330, 1100, 790}' > /dev/null
  hide_others Finder; sleep 1
  arrow $BIN start --element Group --role menubutton --app Finder \
    --text "No, the other grid icon. This one." --from top
  shoot finder "$(frame Finder)"
  close_finder
}

for scene in $SCENES; do "scene_$scene"; done
# README size: 256 colours, then smaller until each file is under 700 KB.
for scene in $SCENES; do
  python3 - "$OUT/$scene.png" <<'PY'
import os, sys
from PIL import Image
path = sys.argv[1]
image = Image.open(path).convert("RGB")
while True:
    image.quantize(256, method=Image.Quantize.MEDIANCUT, kmeans=2).save(path, optimize=True)
    if os.path.getsize(path) < 700_000:
        break
    image = image.resize((int(image.width * 0.85), int(image.height * 0.85)), Image.LANCZOS)
PY
done
ls -la "$OUT"
