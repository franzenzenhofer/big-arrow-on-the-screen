# How to allow screen recording on a Mac

This guide shows how to let an app record your screen on macOS: Google Chrome here, and the same steps work for Zoom, Microsoft Teams, TeamViewer or any other app that shares or records your screen. Every screenshot is a real arrow, drawn by an agent with [bigarrow](../../../README.md) on macOS 27.0.1 (build 26A434). The steps follow Apple's own instructions, [Control access to screen and system audio recording on Mac](https://support.apple.com/guide/mac-help/control-access-screen-system-audio-recording-mchld6aa7d23/mac#:~:text=Choose%20Apple%20menu), checked on 2026-10-09.

## 1. Open Privacy & Security

Choose Apple menu > **System Settings**, then click **Privacy & Security** in the sidebar (scroll the sidebar down if you do not see it).

![System Settings on the General pane, with an arrow at Privacy & Security in the sidebar: 1. Click Privacy & Security](1-privacy-security.png)

```bash
bigarrow start --app "System Settings" --text "1. Click Privacy & Security" \
  --element "Privacy & Security" --role button --from left
```

## 2. Open Screen & System Audio Recording

On the Privacy & Security page, scroll down and click **Screen & System Audio Recording**.

![The Privacy & Security page, with an arrow at the Screen & System Audio Recording row: 2. Click Screen & System Audio Recording](2-screen-recording.png)

```bash
bigarrow start --app "System Settings" --text "2. Click Screen & System Audio Recording" \
  --element "Screen & System Audio Recording" --role button --from right
```

The shortcut an agent uses: one deep link opens this page directly, so steps 1 and 2 happen by themselves.

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
```

## 3. Find the app and switch it on

Find the app in the list and turn on its switch. On: the app may record your screen. Off: it may not. (On this Mac, Chrome's switch is already on.)

![The switch next to Google Chrome, with an arrow: on means Chrome may record your screen](3-switch-on.png)

```bash
bigarrow start --app "System Settings" --text "Chrome's switch: on means Chrome may record your screen" \
  --element "Google Chrome_Toggle" --from right
```

## 4. App not in the list? Click +

Apps usually add themselves to the list the first time they try to record. If yours is missing, click **+** under the list and pick the app in Applications.

![The + button under the list, with an arrow: Chrome missing? Click +](4-add-app.png)

```bash
bigarrow start --app "System Settings" --text "Chrome missing? Click +" --element Add --from bottom
```

## 5. Confirm with your Mac password

When you turn a switch on, macOS shows a sheet: "Privacy & Security is trying to unlock system settings. Enter your password to continue with Privacy & Security." Your user name is already filled in. Type your Mac login password in the Password field and click **Unlock**. If you click **Cancel**, the switch stays off.

![The password sheet, with an arrow at the Password field: Your Mac password here](5-password.png)

```bash
bigarrow start --app "System Settings" --text "Your Mac password here" --at <x,y low in the Password field> \
  --from left --size S --shape straight
```

The shot starts below the user-name field, so no name is in it. To take it, the script pressed the switch of an entry that was off (python3.14), photographed the sheet, clicked Cancel and checked that the switch was off again. No password was typed and no permission was changed.

## 6. Quit & Reopen

If the app is open, macOS then tells you it cannot record your screen until you quit and reopen it. Click **Quit & Reopen**. After that the app can share or record your screen. Apple's page does not show this prompt; it is described, for example, by [UNC Asheville IT](https://kb.unca.edu/kb/allow-an-app-to-record-your-mac-s-screen#:~:text=Quit%20%26%20Reopen). This step is text only: showing it would mean really granting a permission on the test Mac.

## Let your agent do it

The five lines an agent runs to walk a human through this:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
bigarrow elements --app "System Settings" --match Chrome --json      # the switch's id: "Google Chrome_Toggle"
bigarrow start --element "Google Chrome_Toggle" --app "System Settings" --text "Switch this on: Chrome may record your screen" --until-click
bigarrow start --element Password --role textfield --app "System Settings" --text "Your Mac password here" --until-click
bigarrow stop --all
```

`--until-click` takes each arrow down as soon as the human clicks its target. `bigarrow stop --all` cleans up whatever is still up. The screenshots come from [`scripts/guide-screen-recording.sh`](../../../scripts/guide-screen-recording.sh).
