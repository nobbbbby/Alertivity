# Design decisions

## Status

The overall status uses the highest severity among CPU, memory, disk, and network. One busy resource can make the status Critical even when the others are idle. The menu shows the individual readings so you can see which resource caused it.

When several metrics have the same severity, the trigger order is CPU, memory, disk, then network. This fixed order selects notification triggers and breaks ties in status summaries. Auto switch has a separate, customizable priority in **Settings → Menu Bar → Metric priority**; changing it does not change alert selection. [Metrics and status](https://github.com/nobbbbby/Alertivity/wiki/Metrics-and-Status) lists the thresholds and measurement details.

## Alerts

A short spike changes the displayed reading but does not immediately send a notification. System alerts require sustained Critical activity. A shared cooldown then limits how often system and process notifications are attempted. It defaults to ten minutes and can be changed in Settings. This also means a second problem can occur without a second alert.

Auto switch waits for two matching samples before changing the displayed metric. It follows Critical activity and returns to the selected default when that activity ends. See [notification timing](https://github.com/nobbbbby/Alertivity/wiki/Notifications-and-Permissions#when-alerts-are-sent).

## System and process thresholds

System thresholds control the overall status. Process limits determine which executables appear in the high-activity list. A process can exceed its limit while total system usage remains Normal.

Whitelisting a process hides it from process detection; its CPU and memory usage still count in the system readings. The App Store sandbox prevents process sampling, so that build keeps system monitoring without the process controls.

## Onboarding

The welcome guide is optional. Monitoring starts immediately, and skipping the guide does not reset preferences. Notification permission is requested when the user chooses to set up alerts.

The style picker previews a choice until **Use This** is pressed. The guide’s auto-switch toggle, however, saves immediately. These controls have different save behavior, so the apply button stays beside the preview. **Help → Getting Started…** reopens the guide without resetting preferences.

## Threshold editing

Valid edits take effect immediately. If a value is out of range, or Elevated is not below Critical, the app keeps the last valid configuration and displays an error. While correcting an invalid edit, the form can therefore show a value that is not yet active. **Reset to Defaults** restores all system thresholds.

## macOS integration

Settings uses SwiftUI’s Settings scene, login registration uses `SMAppService`, and notifications use the macOS notification center. The app opens System Settings by its bundle identifier and gives navigation instructions instead of using undocumented pane URLs.

Process actions depend on macOS permissions and the process still being available. Termination sends `SIGTERM`, then tries `SIGKILL` only if the first call fails; it does not wait for the process to exit and escalate. See [Process insights](https://github.com/nobbbbby/Alertivity/wiki/Process-Insights#actions).
