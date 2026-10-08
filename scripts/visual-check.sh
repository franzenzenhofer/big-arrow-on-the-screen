#!/bin/bash
# Shows every kind of arrow over a neutral backdrop window and records screenshots of each.
# Meant for a clean machine (CI runner or test Mac), never for a desk somebody works at.
# Usage: scripts/visual-check.sh <out-dir>
set -euo pipefail
OUT="$1"
BIN=.build/release/bigarrow
mkdir -p "$OUT"
swiftc -O scripts/backdrop.swift -o "$OUT/backdrop"
"$OUT/backdrop" &
BACKDROP=$!
trap 'kill $BACKDROP 2>/dev/null || true; $BIN stop --all >/dev/null || true' EXIT
sleep 2
$BIN elements --app backdrop --json > "$OUT/backdrop-elements.json" || true
shot() { sleep "${2:-1.2}"; screencapture -x "$OUT/$1.png"; }
run_case() {
  local name="$1"; shift
  $BIN start "$@" --json > "$OUT/$name.json"
  shot "$name"
  $BIN stop --all > /dev/null
}
run_case bend --at 640,420 --text "Click Allow to continue" --color red
run_case straight --at 640,420 --text "Straight to the point" --shape straight --color blue
run_case zigzag --at 640,420 --text "Over here!" --shape zigzag --color purple
run_case ring --at 640,420 --text "This spot" --style ring --color teal
run_case rect --rect 520,380,240,80 --text "Type your name here" --color green
run_case sharp --at 640,420 --text "Sharp corners" --corners sharp --color yellow
run_case close --at 640,420 --text "Close me with the X" --close-button --color orange
run_case element --element Allow --app backdrop --text "Franz, click Allow" --color green
echo "recorded into $OUT"
