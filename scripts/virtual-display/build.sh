#!/usr/bin/env bash
# Build the virtual-display test helper and list-displays with plain swiftc into ./.build/.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$here/.build"
swiftc -O -swift-version 6 \
  -module-name VirtualDisplay \
  -import-objc-header "$here/CGVirtualDisplayPrivate.h" \
  -framework CoreGraphics -framework Foundation \
  "$here/virtual-display.swift" \
  -o "$here/.build/virtual-display"
swiftc -O -swift-version 6 -module-name ListDisplays \
  "$here/list-displays.swift" -o "$here/.build/list-displays"
echo "built $here/.build/virtual-display and $here/.build/list-displays"
