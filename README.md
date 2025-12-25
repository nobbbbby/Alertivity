# Alertivity

![Screenshot ](<img/menubar.png>)

Alertivity is a macOS menu bar utility that samples CPU, memory, disk, network, and process data so you can spot trouble early. It summarizes system health as Normal/Elevated/Critical, highlights the metric that triggered the state, and offers quick actions on culprit processes.

[![Install directly from the Mac App Store](img/appstore.svg)](https://apps.apple.com/app/alertivity/id6756399719)

## Features
- Live system sampling every few seconds with status driven by the highest-severity metric across CPU, memory, disk, and network (with light hysteresis to avoid flapping).
- Menu bar indicator that can show overall status or a specific metric (CPU, memory, disk, network); optional auto-switch swaps on critical severity only using priority CPU > Memory > Disk > Network and a short dwell, and you can hide the indicator unless status is critical.
- Compact menu showing per-metric summaries, network throughput, and high-activity processes for CPU/memory/network with quick actions to reveal the process in Activity Monitor or terminate it (disk is excluded to avoid slow sampling).
- Notifications for critical status or high-activity processes, including the triggering metric/value and culprit metadata; delivery is throttled to avoid spam.
- Settings tabs for Dock visibility, launch at login, menu icon behavior (default icon type, auto-switch, show-only-on-high-activity, show metric icon), notification opt-in, and detection thresholds (CPU percentage and required duration).

## Requirements
- macOS 13.0 or later (uses `SMAppService` for launch at login)
- Xcode 15 or later with Swift 5 / SwiftUI

## Default thresholds
- Status levels: CPU (<50 / 50–79 / ≥80%), Memory (<70 / 70–84 / ≥85% of total), Disk throughput (<30 MB/s / 30–119 MB/s / ≥120 MB/s aggregated read+write), Network throughput (<5 MB/s / 5–19 MB/s / ≥20 MB/s aggregated send+receive)
- Auto-switch (busiest metric detection): triggers only on Critical severity using the above thresholds, honors priority CPU > Memory > Disk > Network, and requires two consecutive samples before switching
- High-activity process list: CPU ≥80% or Memory ≥25% sustained for 60s

## Build and Run
1) Open `Alertivity.xcodeproj` in Xcode, select the `Alertivity` scheme, and press Run to launch the menu bar app.  
2) From the command line:  
   `xcodebuild -scheme Alertivity -configuration Release -destination 'platform=macOS' build`

## Testing and Coverage
- Full suite with coverage (Swift Testing unit/integration + XCUITest UI smoke):  
  `xcodebuild -project Alertivity.xcodeproj -scheme Alertivity -testPlan Alertivity -destination 'platform=macOS' -enableCodeCoverage YES test`
- UI smoke tests drive a harness window (enabled by the `UITests` launch argument) to toggle menu/notification settings and verify status rendering; run just the UI layer with `-only-testing:AlertivityUITests`.
- Coverage is emitted in the `.xcresult` bundle under DerivedData; unit tests outnumber integration tests (~12:1) and UI tests remain a thin smoke layer to keep the pyramid balanced.

## OpenSpec
- This project uses OpenSpec for change proposals, specs, and implementation tasks. See `openspec/AGENTS.md` for the workflow and `openspec/` for current specs.

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
