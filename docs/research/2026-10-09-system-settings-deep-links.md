# System Settings deep links on macOS 27 - verified

Research date: 2026-10-09, issue #43. Tested on the project's test Mac: macOS 27.0.1, build 26A434 (`sw_vers`).

## Method

For every URL: open a known sentinel pane first (`x-apple.systempreferences:com.apple.preference.sound`, or Displays when the URL under test is Sound), read the title of System Settings' front window through Accessibility, then `open` the URL under test, wait 2.5 s and read the title again:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
osascript -e 'tell application "System Events" to tell process "System Settings" to get name of window 1'
```

"Verified yes" means the window title changed from the sentinel to the pane named in the table. A URL that macOS does not know does nothing visible: `open` still exits 0 and System Settings stays on the previous pane, so the exit code proves nothing; read the title.

## Panes asked for in #43

| URL | Pane actually opened (window title) | Verified |
|---|---|---|
| `x-apple.systempreferences:com.apple.preference.security` | Privacy & Security | yes |
| `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension` | Privacy & Security | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` | Device Control and Data Access | yes |
| `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility` | Device Control and Data Access | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture` | Screen & System Audio Recording | yes |
| `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture` | Screen & System Audio Recording | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles` | Full Disk Access | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Automation` | Automation | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Camera` | Camera | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone` | Microphone | yes |
| `x-apple.systempreferences:com.apple.LoginItems-Settings.extension` | Login Items | yes |
| `x-apple.systempreferences:com.apple.ExtensionsPreferences` | Login Items | yes |
| `x-apple.systempreferences:com.apple.preference.notifications` | Notifications | yes |
| `x-apple.systempreferences:com.apple.Notifications-Settings.extension` | Notifications | yes |
| `x-apple.systempreferences:com.apple.preference.displays` | Displays | yes |
| `x-apple.systempreferences:com.apple.Displays-Settings.extension` | Displays | yes |
| `x-apple.systempreferences:com.apple.preference.keyboard` | Keyboard | yes |
| `x-apple.systempreferences:com.apple.Keyboard-Settings.extension` | Keyboard | yes |
| `x-apple.systempreferences:com.apple.preference.network` | Network | yes |
| `x-apple.systempreferences:com.apple.Network-Settings.extension` | Network | yes |
| `x-apple.systempreferences:com.apple.preferences.Bluetooth` | Bluetooth | yes |
| `x-apple.systempreferences:com.apple.BluetoothSettings` | Bluetooth | yes |
| `x-apple.systempreferences:com.apple.preferences.softwareupdate` | Software Update | yes |
| `x-apple.systempreferences:com.apple.Software-Update-Settings.extension` | Software Update | yes |

## Other panes checked

| URL | Pane actually opened (window title) | Verified |
|---|---|---|
| `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent` | Input Monitoring | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices` | Location Services | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts` | Contacts | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars` | Calendars | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Photos` | Photos | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_DevTools` | Developer Tools | yes |
| `x-apple.systempreferences:com.apple.preference.security?Privacy_Advertising` | Apple Advertising | yes |
| `x-apple.systempreferences:com.apple.wifi-settings-extension` | Wi‑Fi | yes |
| `x-apple.systempreferences:com.apple.preference.universalaccess` | Accessibility | yes |
| `x-apple.systempreferences:com.apple.Accessibility-Settings.extension` | Accessibility | yes |
| `x-apple.systempreferences:com.apple.systempreferences.GeneralSettings` | General (the window title is empty; the sidebar shows General selected, checked on a screenshot) | yes |
| `x-apple.systempreferences:com.apple.preference.general` | Appearance | yes |
| `x-apple.systempreferences:com.apple.preference.battery` | Battery (title also shows the charging state, here "Battery - Charging on Hold") | yes |
| `x-apple.systempreferences:com.apple.preference.sound` | Sound | yes |
| `x-apple.systempreferences:com.apple.Sound-Settings.extension` | Sound | yes |
| `x-apple.systempreferences:com.apple.preference.trackpad` | Trackpad | yes |
| `x-apple.systempreferences:com.apple.preference.mouse` | nothing: stays on the previous pane (Sound) | no |
| `x-apple.systempreferences:com.apple.preference.dock` | Desktop & Dock | yes |
| `x-apple.systempreferences:com.apple.Desktop-Settings.extension` | Desktop & Dock | yes |
| `x-apple.systempreferences:com.apple.Date-Time-Settings.extension` | Date & Time | yes |
| `x-apple.systempreferences:com.apple.Sharing-Settings.extension` | Sharing | yes |
| `x-apple.systempreferences:com.apple.Users-Groups-Settings.extension` | Users & Groups | yes |
| `x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension` | Lock Screen | yes |
| `x-apple.systempreferences:com.apple.preferences.password` | Touch ID & Password | yes |
| `x-apple.systempreferences:com.apple.Focus-Settings.extension` | Focus | yes |
| `x-apple.systempreferences:com.apple.Screen-Time-Settings.extension` | Screen Time | yes |
| `x-apple.systempreferences:com.apple.Siri-Settings.extension` | Siri | yes |
| `x-apple.systempreferences:com.apple.Storage-Settings.extension` | nothing: stays on the previous pane (Sound) | no |
| `x-apple.systempreferences:com.apple.Print-Scan-Settings.extension` | Printers & Scanners | yes |
| `x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane` | Apple Account | yes |
| `x-apple.systempreferences:com.apple.preference.nonexistent` | nothing: stays on the previous pane (Sound) | no |

## Findings

- **Accessibility permission is renamed on macOS 27.** `?Privacy_Accessibility` opens a pane titled **Device Control and Data Access**, not "Accessibility". It lists the apps that may control the Mac (the old Accessibility list) with one switch per app. A sign or a skill that tells a human to look for "Accessibility" under Privacy & Security will send them searching; name the new title.
- `com.apple.preference.universalaccess` opens the separate top-level **Accessibility** pane (VoiceOver, Zoom and so on), not the permission list.
- Screen Recording is titled **Screen & System Audio Recording**.
- Both URL families work: the old `com.apple.preference.*` ids and the newer `com.apple.*-Settings.extension` ids open the same pane. The `?Privacy_*` anchors work on both `com.apple.preference.security` and `com.apple.settings.PrivacySecurity.extension`.
- `com.apple.ExtensionsPreferences` opens Login Items (on macOS 27, Login Items and Extensions share one pane).
- Not verified: `com.apple.preference.mouse` (this Mac has no mouse connected, so there is no Mouse pane to open; untested with a mouse) and `com.apple.Storage-Settings.extension` (does nothing; Storage is reached through General).
- The sidebar of every pane shows the signed-in Apple Account name. Crop it out of any screenshot.
