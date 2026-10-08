#!/bin/bash
# Records the README demo: arrows appearing over a neutral dialog, as a GIF.
# Run on a clean machine only (CI runner), needs ffmpeg and Screen Recording.
# Usage: scripts/record-demo.sh <out-dir>
set -euo pipefail
OUT="$1"
BIN=.build/release/bigarrow
mkdir -p "$OUT"
swiftc -O scripts/backdrop.swift -o "$OUT/backdrop"
"$OUT/backdrop" &
BACKDROP=$!
trap 'kill $BACKDROP 2>/dev/null || true; $BIN stop --all >/dev/null 2>&1 || true' EXIT
sleep 2
# The region around the dialog, in global top-left points.
REGION=$(python3 -c "
import json, subprocess
nodes = json.loads(subprocess.check_output(['$BIN', 'elements', '--app', 'backdrop', '--json']))
(x, y), (w, h) = next(n['frame'] for n in nodes if n.get('role') == 'AXWindow')
print(f'{int(x - 200)},{int(y - 110)},{int(w + 400)},{int(h + 380)}')
")
screencapture -v -V 15 -R "$REGION" "$OUT/demo.mov" &
RECORDER=$!
sleep 1
$BIN point --element Allow --app backdrop --text "Franz, click Allow" --color green --duration 3.5
$BIN point --element Cancel --app backdrop --text "Not this one" --shape zigzag --color purple --from bottom-left --duration 3
$BIN start --element "would like" --app backdrop --text "Read this first" --color orange --close-button --from bottom > /dev/null
sleep 3
$BIN stop --all > /dev/null
wait $RECORDER
ffmpeg -loglevel error -y -i "$OUT/demo.mov" \
  -vf "fps=15,scale=760:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer" \
  "$OUT/demo.gif"
ls -la "$OUT/demo.gif"
