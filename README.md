# Alertivity

Alertivity is a macOS menu bar utility that samples CPU, memory, disk, network, and process data so you can spot trouble early. It summarizes system health as Normal/Elevated/Critical, highlights the metric that triggered the state, and offers quick actions on culprit processes.

## Features
- Live system sampling every few seconds with status driven by the highest-severity metric across CPU, memory, and disk.
- Menu bar indicator that can show overall status or a specific metric (CPU, memory, disk, network); optional auto-switch picks the busiest metric using priority CPU > Memory > Network > Disk, and you can hide the indicator unless status is critical.
- Compact menu showing per-metric summaries, network throughput, and high-activity processes for CPU/memory/network with quick actions to reveal the process in Activity Monitor or terminate it (disk is excluded to avoid slow sampling).
- Notifications for critical status or high-activity processes, including the triggering metric/value and culprit metadata; delivery is throttled to avoid spam.
- Settings tabs for Dock visibility, launch at login, menu icon behavior (default icon type, auto-switch, show-only-on-high-activity, show metric icon), notification opt-in, and detection thresholds (CPU percentage and required duration).

## Requirements
- macOS 13.0 or later (uses `SMAppService` for launch at login)
- Xcode 15 or later with Swift 5 / SwiftUI

## Default thresholds
- Status levels: CPU (<50 / 50–79 / ≥80%), Memory (<70 / 70–84 / ≥85% of total), Disk (<85 / 85–94 / ≥95% of total)
- Auto-switch (busiest metric detection): CPU if ≥60%, Memory ≥80%, Network total ≥5 MB/s, Disk ≥90% used
- High-activity process list: CPU ≥20% sustained for 120s (Memory threshold is 15% but CPU drives the default rule)

## Build and Run
1) Open `Alertivity.xcodeproj` in Xcode, select the `Alertivity` scheme, and press Run to launch the menu bar app.  
2) From the command line:  
   `xcodebuild -scheme Alertivity -configuration Release -destination 'platform=macOS' build`

## Using the App
- First launch: choose whether to hide the Dock icon, enable launch at login, and allow notifications if desired.
- Menu bar: pick a default icon (status or a metric) or turn on Auto switch so the indicator follows the busiest metric; optionally show the indicator only when status is critical.
- Status: the menu status row explains which metric triggered the elevated/critical state and lists CPU, memory, disk percentages plus network throughput.
- Processes: high-activity items require sustained load before appearing; buttons let you open Activity Monitor focused on the process or force quit it.
- Notifications: fire on critical status or when a tracked process crosses the high-activity rule; include trigger metadata and process actions.

## Privacy and Permissions
- Activity Monitor reveal uses AppleScript through System Events; grant Accessibility permission to Alertivity if prompted so the search shortcut works.
- Notifications require user authorization; enable them in Settings > Notifications.
- Launch at login depends on macOS 13+; if registration fails, the app re-reads the system status to keep the toggle accurate.
