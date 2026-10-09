#!/bin/bash
# Real arrows over real backgrounds, captured from the screen: plain white, macOS grey, dark,
# black, saturated red, and a busy web page. Shows the default look (white border and drop
# shadow), --border white-black and black, --close-button, custom colours and a black arrow.
# Run only on a disposable machine (the CI runner). Usage: scripts/look-check.sh <out-dir>
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
mkdir -p "$OUT"
swiftc -O scripts/backdrop.swift -o "$OUT/backdrop"
perl -e 'alarm shift; exec @ARGV' 60 "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
  --window-size=1440,900 --screenshot="$OUT/page.png" "https://en.wikipedia.org/wiki/Arrow" > /dev/null 2>&1
trap '$BIN stop --all > /dev/null 2>&1; pkill -f "$OUT/backdrop"' EXIT

LOOKS=(
  "default|--color red"
  "white-black|--color red --border white-black"
  "black-line|--color red --border black"
  "close|--color red --close-button"
  "custom|--color blue --border-color yellow --text-color yellow"
  "black|--color black"
)
BACKGROUNDS=("white|--cover-color FFFFFF" "grey|--cover-color F2F2F7" "dark|--cover-color 1E1E1E"
  "black|--cover-color 000000" "red|--cover-color E53935" "page|--cover-image $OUT/page.png")

for background in "${BACKGROUNDS[@]}"; do
  IFS='|' read -r BG_NAME BG_ARGS <<< "$background"
  # shellcheck disable=SC2086
  "$OUT/backdrop" --cover $BG_ARGS & BACKDROP=$!
  sleep 3
  for look in "${LOOKS[@]}"; do
    IFS='|' read -r LOOK_NAME LOOK_ARGS <<< "$look"
    # shellcheck disable=SC2086
    $BIN start --element Allow --app backdrop --text "Franz, click Allow" --no-animation $LOOK_ARGS > /dev/null
    sleep 0.8
    screencapture -x "$OUT/$BG_NAME-$LOOK_NAME.png"
    $BIN stop --all > /dev/null
  done
  kill $BACKDROP; wait $BACKDROP 2>/dev/null
done
ls "$OUT" | wc -l
