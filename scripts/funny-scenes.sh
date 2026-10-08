#!/bin/bash
# Stages the README's "real-world situations": a neutral dialog plus arrows, one screenshot
# each, full screen. Clean machines only (CI runner), never a desk in use.
# Usage: scripts/funny-scenes.sh <out-dir>
set -uo pipefail
OUT="$1"
BIN=.build/release/bigarrow
mkdir -p "$OUT"
swiftc -O scripts/backdrop.swift -o "$OUT/backdrop"
BACKDROP=""
trap '[ -n "$BACKDROP" ] && kill $BACKDROP 2>/dev/null; $BIN stop --all >/dev/null 2>&1' EXIT

scene() {
  local name="$1" title="$2" message="$3" buttons="$4"; shift 4
  [ -n "$BACKDROP" ] && kill $BACKDROP 2>/dev/null
  "$OUT/backdrop" --title "$title" --message "$message" --buttons "$buttons" & BACKDROP=$!
  sleep 2.5
  "$@"
  sleep 1.6
  screencapture -x "$OUT/$name.png"
  $BIN stop --all > /dev/null
}

scene node-modules "Terminal Helper" "Delete node_modules? This will free 3.4 GB and 847,293 files you have never opened." "Keep,Delete" \
  $BIN start --element Delete --app backdrop --text "Yes. Obviously." --color green --no-animation

scene cookies "Some Website" "We value your privacy. That is why we have 1,142 partners who also value your privacy." "Manage options,Accept all" \
  $BIN start --element "Manage options" --app backdrop --text "Franz, nobody reads these either" --shape zigzag --color orange --from bottom-left --no-animation

scene two-factor "Sign in" "Enter the 6-digit code we just sent to the phone that is in your other jacket." "Cancel,Verify" \
  $BIN start --element Verify --app backdrop --text "This is where you sigh and find your phone" --color purple --no-animation

scene agent-needs-you "Deploy" "Deploying to production on a Friday at 17:55. Continue?" "Cancel,Deploy" \
  $BIN start --element Cancel --app backdrop --text "The agent strongly suggests this one" --color red --close-button --from bottom-left --no-animation

scene which-button "Save changes?" "Do you want to save the changes you made to Untitled 37?" "Don't Save,Cancel,Save" \
  bash -c "$BIN start --element Save --app backdrop --role button --text 'This one' --color blue --from top-right --no-animation > /dev/null; \
           $BIN start --element Save --app backdrop --role button --text 'Yes, this one' --color purple --shape straight --from bottom-left --no-animation > /dev/null; \
           $BIN start --element Save --app backdrop --role button --text 'Seriously. THIS one.' --color red --shape zigzag --from bottom-right --no-animation > /dev/null"

scene permissions "System Settings" "\"Terminal\" would like to control this computer using accessibility features." "Deny,Open System Settings" \
  $BIN start --element "Open System Settings" --app backdrop --text "Grant it to Terminal, not to bigarrow" --style box --color teal --corners sharp --no-animation
ls "$OUT"
