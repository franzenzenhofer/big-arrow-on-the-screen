# Spike 2026-10-08: click-through arrow overlay from a plain CLI process

Throwaway feasibility probe written during planning. It is NOT the product and is not built by the package. It exists so the plan can say "verified" instead of "should work".

## What was run

```bash
swiftc -O -o probe probe.swift        # 3.4 s wall clock, Swift 6.3.1, macOS 26.1
./probe 760 500 &                     # target in global top-left points, exits after 6 s
swiftc -o wincheck wincheck.swift && ./wincheck
```

## What was observed

- A big curved arrow with a rounded sign reading "Franz, click HERE" rendered above Google Chrome on the built-in display.
- No Dock icon, no focus change, Chrome stayed frontmost (`NSApplication.setActivationPolicy(.accessory)`).
- Window server listing (`wincheck`): `owner=probe layer=1000 bounds={X=0 Y=0 Width=1512 Height=982} alpha=1`, so the window sits at `NSWindow.Level.screenSaver` and covers the whole display.
- No permission prompt of any kind appeared (drawing needs neither Screen Recording nor Accessibility).
- Binary size 70,616 bytes.
- The process exited on its own after the 6 s timer.

The screenshot taken during the run showed personal content (an inbox) and is therefore not committed. Ticket T03 re-records the proof over a neutral window.

## Settings that made it work

`.borderless` style, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`, `ignoresMouseEvents = true`, `level = .screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `orderFrontRegardless()`. The product version (ticket T04) upgrades this to a non-activating `NSPanel` with `.canJoinAllApplications` per Apple DTS guidance, see `docs/research/2026-10-08-macos-overlay-apis-and-prior-art.md`.
