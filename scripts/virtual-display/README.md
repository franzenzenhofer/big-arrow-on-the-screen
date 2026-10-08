# virtual-display

Test helper that adds a temporary virtual display, so multi-display behaviour of `bigarrow` can be
checked on a Mac with only its built-in screen. It uses the private CoreGraphics classes
`CGVirtualDisplayDescriptor`, `CGVirtualDisplaySettings`, `CGVirtualDisplayMode` and `CGVirtualDisplay`
(macOS 11+). This is a test tool only. It is not part of the shipped CLI.

## Build

```bash
scripts/virtual-display/build.sh
# -> scripts/virtual-display/.build/virtual-display
# -> scripts/virtual-display/.build/list-displays
```

This is plain `swiftc` (Swift 6 language mode). The private interfaces come in through
`-import-objc-header CGVirtualDisplayPrivate.h`, so no Xcode project and no SwiftPM are needed.

## Run

```bash
virtual-display --width 1920 --height 1080 --hidpi 0 --seconds 8 [--origin x,y]
```

- `--width/--height`: the logical size in points. With `--hidpi 1`, the backing mode is 2x in pixels.
- `--origin x,y`: the top-left corner in global top-left points (main display at 0,0). For example,
  `--origin 0,-1080` puts the display above the main display. By default it goes to the right of the
  main display. macOS may snap the origin so the displays touch, so trust the printed frame and not
  the value you passed in.
- Once the display is active, extended (not mirrored) and the previous main display is still main,
  it prints one JSON line to stdout. The frame comes from `CGDisplayBounds`:
  `{"displayID":6,"frame":{"x":1512,"y":0,"width":1920,"height":1080}}`
- It lives for `--seconds`, or until SIGINT/SIGTERM/SIGHUP, and then exits. Diagnostics go to stderr.
- It fails hard (exit 1, with the reason on stderr) if the display does not come up, if the
  requested mode does not exist, or if the layout does not settle within 5 seconds.

Smoke test (always in the foreground, with a timeout):

```bash
D=scripts/virtual-display/.build
timeout 20 $D/virtual-display --width 1920 --height 1080 --hidpi 0 --seconds 8 > /tmp/vd.json 2> /tmp/vd.err &
PID=$!; sleep 3
cat /tmp/vd.json; $D/list-displays          # expect 2 online displays
wait $PID; echo "exit=$?"; cat /tmp/vd.err
$D/list-displays                            # expect 1 display again
```

## Safety

- Every display change is one transaction finished with `CGCompleteDisplayConfiguration(config, .forSession)`.
  The code never uses `kCGConfigurePermanently`.
- On this machine, macOS brought the new display up as the **mirror master and main display**:
  the built-in screen hardware-mirrored it for a moment. In the same session-only transaction, the
  helper breaks every mirror that involves the new display, keeps the previous main display at (0,0)
  (the display at the origin is the main one) and places the virtual display. Expect one short flash
  on the real screen when it starts.
- The display is removed when the process exits, because its window-server connection closes.
  When `CGVirtualDisplay` was released inside the still-running process, the display had not
  disappeared after 5 s, so the helper releases it and then exits. Killing it with SIGKILL also
  removes it, because removal comes from the process ending.

## Caveats

- The API is private and undocumented, so it can change with any macOS release.
- No TCC permission is needed to create the display or to read `CGDisplayBounds`/`NSScreen`.
  Screen Recording only matters if you want to capture the virtual display's pixels (DeskPad
  does that with `CGDisplayStream`). It is a blank framebuffer that nobody can see.
- `--hidpi 1` follows the pixel-doubled mode approach that hidpi-mirror uses, and it picks the mode
  whose `pixelWidth == 2 * width`. This path compiles, but it has not been run yet.

## Sources (read for this helper)

- DeskPad by Bastian Andelefski (Stengo), MIT. Private header and usage (descriptor, settings, modes, `setDispatchQueue`):
  https://github.com/Stengo/DeskPad/blob/c3349f0e237e000cb4826fb3ea1cdd1c44949461/DeskPad/CGVirtualDisplayPrivate.h
  https://github.com/Stengo/DeskPad/blob/c3349f0e237e000cb4826fb3ea1cdd1c44949461/DeskPad/Frontend/Screen/ScreenViewController.swift
- KhaosT/CGVirtualDisplay, Apache-2.0, the original example that the DeskPad header comes from (includes `terminationHandler`):
  https://github.com/KhaosT/CGVirtualDisplay/blob/ec72be5f546d1aa1257f9976fea86a2de9dab35c/VirtualDisplayExp/CGVirtualDisplayPrivate.h
  https://github.com/KhaosT/CGVirtualDisplay/blob/ec72be5f546d1aa1257f9976fea86a2de9dab35c/VirtualDisplayExp/ViewController.swift
- pasky/hidpi-mirror, MIT. HiDPI through 2x pixel modes plus `kCGDisplayShowDuplicateLowResolutionModes` mode lookup:
  https://github.com/pasky/hidpi-mirror/blob/13acfaa0ec4b13bfce84554beebc8a09813cc2ae/hidpi-mirror.m
