# Peekaboo 4.9.0, Nameplate and the OpenClaw skill format - what exists and what to reuse

Research date: 2026-10-08. Source: shallow clone of `openclaw/Peekaboo` at commit `c02c269` (2026-10-07, `version.json` 4.9.0, MIT, 5262 stars) plus the linked GitHub files. Line numbers refer to that commit.

## TL;DR for the reuse / depend / fork / build decision

- Peekaboo has no "draw an arrow with a label at X, stay until dismissed" feature. Its visualizer is a closed catalog of 16 short-lived, auto-fading animations. Only `elementDetection` draws at an arbitrary rect, and the only text it can show is the element id in 10pt type. No open issue or PR asks for an arrow, pointer, annotate or guide overlay.
- Drawing requires Peekaboo.app (23 MB menu-bar app, bundle `boo.peekaboo.mac`) to be running; the 36 MB CLI never draws anything itself. Transport is a JSON file plus `DistributedNotificationCenter`, best effort, events dropped if the app is absent. "There is no auto-launch of Peekaboo.app." https://github.com/openclaw/Peekaboo/blob/main/docs/bridge-host.md
- Worth depending on at the CLI level: `peekaboo see --json` (element map with `ui_elements[].bounds` in top-left global points, ids `B1`/`T2`/`L3`), `peekaboo window list --app X --json`, `peekaboo screen list --json`.
- Overlay windows need no TCC permission (plain `NSWindow`, `.borderless`, `.screenSaver`, `ignoresMouseEvents`). Only Accessibility lookup needs a permission, screenshots need Screen Recording.
- Peter Steinberger's Nameplate (MIT, pushed 2026-10-07) is closer to the goal than Peekaboo: click-through `NSPanel`s on every screen and a `nameplate attention "msg" --title --duration --color` CLI that stays up until clicked. No arrow and no point-at-coordinate there either, but its panel factory and handoff design are the pattern to copy. https://github.com/steipete/Nameplate
- Recommendation: build fresh, depend on `peekaboo see` and `window list` optionally for target resolution, copy Nameplate's panel settings. Forking Peekaboo would drag in a 36 MB binary, a Bridge daemon, Tachikoma, MCP and a Developer ID release pipeline.

## 1. Visualizer architecture

- Renderer lives in the Mac app: `VisualizerCoordinator()` and `VisualizerEventReceiver` created in `Apps/Mac/Peekaboo/PeekabooApp.swift:259-261`. https://github.com/openclaw/Peekaboo/blob/main/Apps/Mac/Peekaboo/PeekabooApp.swift No hidden helper app for overlays.
- Transport: "Distributed notifications (`boo.peekaboo.visualizer.event`) + shared JSON envelopes written by `VisualizationClient`"; "Events live in `~/Library/Application Support/PeekabooShared/VisualizerEvents`". `docs/visualizer.md:23-24` https://github.com/openclaw/Peekaboo/blob/main/docs/visualizer.md Code: `VisualizerEventStore.swift:134`, `VisualizationClient.swift:234-240`, `VisualizerEventReceiver.swift:30`.
- App not running: `canDispatchEvents` scans running apps for bundle prefix `boo.peekaboo.mac`; otherwise logs "Peekaboo.app is not running; visual feedback unavailable until it launches" and drops the event. `VisualizationClient.swift:103-105, 231, 365-370`.

## 2. How the overlay windows are built

`Core/PeekabooVisualizer/Sources/PeekabooVisualizer/Renderer/AnimationOverlayManager.swift:106-121` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooVisualizer/Sources/PeekabooVisualizer/Renderer/AnimationOverlayManager.swift

```swift
let window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
window.isOpaque = false
window.backgroundColor = .clear
window.level = .screenSaver
window.ignoresMouseEvents = true
window.hasShadow = false
window.isReleasedWhenClosed = false
window.canHide = false
```

- Plain `NSWindow`, `collectionBehavior` not set, so overlays stay on the current Space and do not appear over another app's full-screen Space.
- Content is SwiftUI in an `NSHostingView` (`:66-72`); removal is `Task.sleep` then an alpha fade (`:84-101, 124-133`).
- Per screen: element sheets open one overlay window per display whose frame intersects an element. `VisualizerCoordinator+SystemDisplays.swift:14-37` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooVisualizer/Sources/PeekabooVisualizer/Renderer/VisualizerCoordinator+SystemDisplays.swift
- Coordinate flip is done once, sender side, against the primary display: `CGPoint(x: point.x, y: primaryScreenFrame.maxY - point.y)`, rect `y: primaryScreenFrame.maxY - rect.maxY`. `GlobalScreenCoordinateGeometry.swift:16, 35-39` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooFoundation/Sources/PeekabooFoundation/GlobalScreenCoordinateGeometry.swift The flip axis is `NSScreen.screens[0]`, "not `NSScreen.main`" (`docs/visualizer.md:228-232`).
- A second, older overlay in `PeekabooUICore` for the Inspector uses `level = .floating`, `ignoresMouseEvents`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]` and `.nonactivatingPanel`. `OverlayWindowController.swift:88-109` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooUICore/Sources/PeekabooUICore/Overlay/OverlayWindowController.swift

## 3. Visualizer event catalog, and the arrow question

16 kinds (`VisualizerEventStore.swift:23-38, 89-130`): screenshotFlash, watchCapture, clickFeedback, typingFeedback, scrollFeedback, mouseMovement, swipeGesture, hotkeyDisplay, appLaunch, appQuit, windowOperation, menuNavigation, dialogInteraction, spaceSwitch, elementDetection, annotatedScreenshot.

Can any draw an arbitrary arrow plus custom label at a coordinate, custom duration, sticky until dismissed? No.
- No arrow primitive. The only "arrow" strings are SF Symbol names for scroll chevrons, keycap glyphs and the cursor polygon.
- Nearest match `elementDetection`: outline sized to the rect with the element id in `.system(size: 10)` above it, auto-fades, capped at 120 rects, OFF unless `PEEKABOO_VISUAL_ELEMENT_BOXES=true`. `Views/ElementHighlightView.swift:22-33` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooVisualizer/Sources/PeekabooVisualizer/Views/ElementHighlightView.swift
- Durations are scaled and capped; every window is scheduled for removal in `showAnimation`. No sticky mode.
- `peekaboo visualizer` has no options: it runs a fixed 5-step smoke sequence and exits 1 if the app is not running. `VisualizerCommand.swift:14-24, 74-80, 98-106` https://github.com/openclaw/Peekaboo/blob/main/Apps/CLI/Sources/PeekabooCLI/Commands/System/VisualizerCommand.swift No MCP tool draws overlays.
- Docs on click feedback: "No labels", there is no "Click" text. `docs/visualizer.md:125-130`

## 4. `see`, `window list`, `screen list` JSON shapes (4.9.0)

- `peekaboo see --json` top level: `snapshot_id`, `ui_elements[]`, `focused_element`, `coordinate_context`, `interactable_count`, `element_count`, `screenshot_raw`, `screenshot_annotated`. `docs/commands/see.md:203-213` https://github.com/openclaw/Peekaboo/blob/main/docs/commands/see.md
- Each `ui_elements[n]`: `id`, `role`, `ax_role`, `title`, `label`, `value`, `description`, `role_description`, `identifier`, `confidence`, `bounds {x, y, width, height}`, `is_actionable`, `is_enabled`, `is_selected`, `keyboard_shortcut`. `UIElementSummary.swift:9-27, 96-108` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooCore/Sources/PeekabooAgentRuntime/Support/UIElementSummary.swift
- Ids: prefix B button, T textInput, L link, C checkbox, R radioButton, S slider, M menu, I image, G container, X text, U custom. `ElementVisualization.swift:130-153`
- `bounds` are global display logical points, origin top-left of the primary display: "Element bounds use global accessibility coordinates (top-left origin)" `SeeTool.swift:491` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooCore/Sources/PeekabooAgentRuntime/MCP/Tools/SeeTool.swift and `docs/MCP.md:287-298` (`origin: "top_left"`). Exception: with `--roi` bounds are ROI-local.
- The installed Peekaboo 3.0.0-beta3 on this Mac omits `bounds` in `see --json` (verified 2026-10-08).
- Resolving "the Save button in Safari": `peekaboo see --app Safari --json | jq '.data.ui_elements[] | select(.label|test("Save";"i")) | .bounds'` (`docs/commands/see.md:216-224`); `click` uses lowercase substring matching on title/label/value/role sorted top to bottom. `SnapshotManager+Elements.swift:26-40` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/Support/SnapshotManager+Elements.swift
- `window list --app X --json`: `windows[] { window_title, window_id, window_index, bounds {x,y,width,height}, is_on_screen, screen_index, is_frontmost, layer }`. `Application.swift:10-23, 98-102` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Core/Models/Application.swift
- `screen list --json`: `screens[] { index, name, displayID, bounds, visibleBounds, scaleFactor, isPrimary }`, "upper-left-origin global logical coordinate space". `docs/commands/screen.md:19-23` https://github.com/openclaw/Peekaboo/blob/main/docs/commands/screen.md

## 5. Permissions in Peekaboo

- Screen Recording via `CGPreflightScreenCaptureAccess()`, Accessibility via `AXIsProcessTrusted()` (AXorcist), Event Synthesizing via `CGPreflightPostEventAccess()`. `PermissionsService.swift:20-34, 200-207` https://github.com/openclaw/Peekaboo/blob/main/Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/System/PermissionsService.swift
- The CG preflight "is unreliable for CLI tools ... TCC tracks by code signature", so they probe `SCShareableContent` as a fallback. `ScreenCapturePermissionGate.swift:87-91`
- Drawing the overlay touches no TCC API.

## 6. Build and distribution of Peekaboo

- `swift-tools-version: 6.2`, strict concurrency, `defaultIsolation(MainActor.self)`. `Package.swift:1-15` https://github.com/openclaw/Peekaboo/blob/main/Package.swift macOS 15+, Xcode 26.x. `docs/building.md:10-16`
- Distribution: `brew install openclaw/tap/peekaboo`, `npx -y @steipete/peekaboo mcp`, DMG for the app. `docs/install.md:14-37` https://github.com/openclaw/Peekaboo/blob/main/docs/install.md
- Signing: "Every shipped macOS code object uses `Developer ID Application: OpenClaw Foundation (FWJYW4S8P8)`", all notarized. `docs/RELEASING.md:9-12` https://github.com/openclaw/Peekaboo/blob/main/docs/RELEASING.md
- Size: v4.9.0 CLI arm64 36,407,984 bytes; app zip 23.3 MB.

## 7. Existing arrow, pointer, annotate, guide feature or issue in Peekaboo

Not found. File-name grep hits are unrelated (`HeldPointer*`, `ObservationAnnotationRenderer` draws boxes onto saved PNGs, `LearnCommand.guide` prints text). The roadmap in `docs/visualizer.md:380-467` lists element highlight animations, menu highlights and sound effects, nothing about guiding a human. `gh issue list -R openclaw/peekaboo --search "arrow overlay highlight pointer annotate" --state all` returned an empty list; only 5 open issues total.

## 8. Related repos

| Repo | One-liner | Relevance |
|---|---|---|
| steipete/Nameplate (MIT, pushed 2026-10-07) | "Brand every Mac in your fleet - colored frame, name tag, watermark, and connect splash as click-through overlays." | Closest prior art. `OverlayPanelFactory.makePanel`: `NSPanel(styleMask: [.borderless, .nonactivatingPanel])`, clear, no shadow, `ignoresMouseEvents = true`, `hidesOnDeactivate = false`, `isFloatingPanel = true`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` https://github.com/steipete/Nameplate/blob/main/Sources/Nameplate/OverlayController.swift `nameplate attention <message> [--title] [--duration] [--color]`: "No duration = sticky", dismissed by click https://github.com/steipete/Nameplate/blob/main/Sources/Nameplate/AttentionController.swift Transport: JSON request in a handoff dir plus Darwin notification, CLI cold-launches the app and waits for an ack https://github.com/steipete/Nameplate/blob/main/Sources/NameplateCLI/main.swift |
| openclaw/AXorcist (0.2.1) | "Swift wrapper for macOS Accessibility - chainable, fuzzy-matched queries" | Option for in-process AX lookup. https://github.com/openclaw/AXorcist/blob/main/Sources/AXorcist/Core/AXPermissionHelpers.swift |
| steipete/fluegel | "Mac app to elevate permissions, when your cli needs wings." TCC broker. https://github.com/steipete/fluegel | Only if AX lookups should run under a stable signed identity. |
| steipete/sag | "Like the macOS say command, but with a modern voice." | Optional `--say` backend. |
| openclaw/openclaw | bundled `skills/peekaboo/SKILL.md` | Example of the OpenClaw skill format. |
| openclaw/clawhub | "Skill + Plugin Registry for OpenClaw" | Publish target. |

## OpenClaw SKILL.md structure

From https://github.com/openclaw/openclaw/blob/main/docs/tools/skills.md and the bundled example https://github.com/openclaw/openclaw/blob/main/skills/peekaboo/SKILL.md:

```yaml
---
name: peekaboo
description: "Capture and automate macOS UI with the Peekaboo CLI."
homepage: https://peekaboo.boo
metadata:
  { "openclaw": { "emoji": "👀", "os": ["darwin"], "requires": { "bins": ["peekaboo"] },
      "install": [ { "id": "brew", "kind": "brew", "formula": "steipete/tap/peekaboo", "bins": ["peekaboo"], "label": "Install Peekaboo (brew)" } ] } }
---
```

Required: `name`, `description`. Optional: `homepage`, `user-invocable`, `disable-model-invocation`, `command-dispatch`, `metadata.openclaw` with `os`, `requires.bins`, `install[]` of kind `brew|node|go|uv|download`.
