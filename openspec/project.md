# Project Context

## Purpose
Alertivity is a macOS menu bar utility that continuously samples CPU, memory, disk, network, and process data so people can see when their Mac is drifting into trouble. It summarizes system health as Normal/Elevated/Critical, highlights culprit processes, and offers quick actions (open Activity Monitor or terminate the process) plus optional user notifications when thresholds are exceeded.

## Tech Stack
- Swift 5.* with SwiftUI for the application shell, menu bar extra, and settings UI
- AppKit interop (e.g., `NSApp`, `NSWorkspace`, `NSWindow`, `NSMenuBarExtra`) to manage Dock visibility, menu insertion, app activation, and process icons
- Combine/ObservableObject publishers for live metrics (`ActivityMonitor`) and menu labels
- `ServiceManagement.SMAppService` for launch-at-login support, `UserNotifications` for alerts, and Darwin/mach APIs (`host_processor_info`, `vm_statistics64`, `getifaddrs`, `ps`) for system data
- Menu bar uses `MenuBarExtra` with `.window` style; settings use `TabView` with per-tab helper notes; macOS 14 `SettingsLink` is used when available
- Menu bar metric labels are rendered with SwiftUI for CPU/memory/disk and a custom `NSImage` renderer for stacked network throughput text to keep the indicator compact
- Targets macOS 13+ (for SMAppService); uses `MenuBarExtra` with `.window` style and opts into macOS 14 `SettingsLink` when available
- Timer-driven sampling (5s default) on the main run loop; metrics work stays on a private background queue to avoid blocking UI updates
- Preferences stored via `@AppStorage` (menu visibility, notification opt-in, icon styling, high-activity thresholds/duration) with namespaced keys
- No third-party dependencies; Foundation, AppKit, and SwiftUI are the only frameworks

## Project Conventions

### Principles
- Prefer the latest stable macOS APIs, Swift features, and supporting tools when available, and rely on MCP Context7 documentation to stay current rather than keeping legacy patterns for convenience.
- Use Conventional Commits for commit messages (e.g., `feat:`, `fix:`, `chore:`) unless a repository-specific template overrides it.

### Code Style
- Swift style follows standard Apple conventions: `UpperCamelCase` types, `lowerCamelCase` members, and descriptive enum cases such as `.critical`
- Use `struct` + `enum` for immutable value types (`ActivityMetrics`, `ActivityStatus`, `MenuIconType`) and `final class` for observable state (`ActivityMonitor`, `NotificationManager`)
- Keep view structs lightweight and extract reusable subviews (`MenuMetricRow`, `MetricMenuBarLabel`) instead of monolithic view bodies
- Persist preferences with `@AppStorage`, prefer dependency injection defaults (e.g., passing a `SystemMetricsProvider` into `ActivityMonitor`), and keep I/O work off the main thread
- Clamp user-tunable inputs (1–100% CPU thresholds, 10–600s durations) before applying changes to state
- Use `Measurement`/`ByteCountFormatter`/`MeasurementFormatter` for storage/throughput display to keep units consistent

### Architecture Patterns
- `AlertivityApp` hosts a `MenuBarExtra` scene and macOS Settings pane; it wires state objects (`ActivityMonitor`, `NotificationManager`) into SwiftUI views
- `SystemMetricsProvider` encapsulates sampling logic (CPU/memory/disk/network/process) and throttling, while `ActivityMonitor` orchestrates timers and publishes sanitized `ActivityMetrics`
- Views bind to published metrics/status and render menu rows, detail panels, and settings tabs; menu labels are driven by `MenuIconType`/`MetricMenuSelection` enums for consistency, including auto-switch fallback to the default icon when nothing is “busy”
- Notification delivery, Activity Monitor reveal, and process termination live in isolated helper types (`NotificationManager`, `ProcessActions`) so UI code stays declarative
- `ActivityMonitor` fetches on a background queue, publishes on the main thread, and caches last snapshots to smooth transient zero readings
- `SystemMetricsProvider` tracks CPU/network/disk snapshots and enforces high-activity dwell time via `processActivityStartTimes` to avoid flickering process lists
- `NotificationManager` throttles alerts (10m), attaches process metadata for actions, and routes user actions through `ProcessActions`
- Menu indicator auto-switch uses deterministic priority CPU > Memory > Network > Disk; “high activity” for this selector is CPU ≥60%, Memory ≥80%, Disk ≥90% full, Network ≥ ~5 MB/s

### Testing Strategy
- Run the macOS build and full test suite with coverage in one step via `xcodebuild -project Alertivity.xcodeproj -scheme Alertivity -configuration Debug -destination 'platform=macOS' -enableCodeCoverage YES test`; use this locally and in CI so build failures and regressions surface automatically.
- For a quicker compile-only check, `xcodebuild -project Alertivity.xcodeproj -scheme Alertivity -configuration Debug -sdk macosx build` is fine before iterating on UI or manual runs.
- SwiftUI previews in each view file are used for quick visual checks of menu/status layouts and settings forms
- When making platform API changes, build/run on macOS 13+ to confirm launch-at-login, dock visibility, and notification permissions still behave
- After automated checks, perform a debug run to ensure the app compiles cleanly and logging behaves before relying on manual runtime checks
- Manually validate high-activity detection (sustain CPU above threshold for the configured duration) to confirm process rows and notification actions fire
- Confirm AppleScript-driven Activity Monitor search still focuses the process list and respects accessibility permissions

### Git Workflow
- Follow lightweight GitHub Flow: branch from `main`, use `feature/<short-description>` names, and keep commits small and descriptive
- Open pull requests for every change so reviewers can validate UI behavior and confirm `openspec` docs stay current
- Avoid force-pushing to `main`; rebase/merge on your feature branch as needed before landing

## Domain Context
Alertivity targets Mac power users who want early warning signs that something is bogging down their machine. CPU load primarily determines status, but menu data also includes memory footprint, disk usage, network throughput, and a curated list of “high activity” processes that cross a configurable CPU threshold for a sustained duration. Notifications can be throttled, and menu icons can either mirror overall status or pin a specific metric (CPU, memory, disk, network, process count).
- Status thresholds: CPU (<50 / 50–79 / ≥80%), Memory (<70 / 70–84 / ≥85%), Disk (<85 / 85–94 / ≥95%). High-activity processes default to ≥20% CPU sustained for 120s (user-adjustable); memory uses a 15% threshold for severity and inclusion.
- Auto-switch “busiest metric” thresholds: CPU ≥60%, Memory ≥80%, Disk ≥90% full, Network total ≥ ~5 MB/s; priority order CPU > Memory > Network > Disk.
- Status messaging: notification titles use sentence case (e.g., "Multiple metrics elevated"), menu titles use title case (e.g., "Multiple Metrics Elevated"), and mixed severity titles collapse repeated levels to "Multiple metrics critical/elevated" when 2+ metrics share a level. Menu summaries use threshold-based sentences for single metrics and concise "over X" clauses with "(critical)/(elevated)" tags for multi-metric states, while notification bodies list live values with "(crit)/(elev)" tags.
- Menu bar visibility can be gated to critical-only; detail rows show metric gauges plus high-activity processes with quick actions to reveal or terminate.

## Important Constraints
- Launch-at-login toggling uses `SMAppService` and therefore requires macOS 13+; guard code paths appropriately
- `SystemMetricsProvider` shells out to `/bin/ps`, reads mach host statistics, and enumerates network interfaces—keep that work off the main thread and be mindful of sandbox entitlements
- AppleScript automation is used to drive Activity Monitor searches; changing the script can require updated accessibility permissions, so avoid unnecessary churn
- The app intentionally hides the Dock icon only when no regular windows are visible; always re-activate the app if a visible window appears to keep the UX compliant with AppKit expectations
- `ps` sampling is bounded by a 2s timeout; use cached metrics on failure to keep UI responsive
- Notification throttling (10m) prevents spam; launch-at-login failures fall back to `SMAppService.mainApp.status` when syncing preferences
- Notifications include critical-process actions (“Show in Activity Monitor”, “Force Quit Process”) and carry process metadata; keep category identifiers stable to avoid breaking action handling

## External Dependencies
- macOS frameworks: SwiftUI, AppKit, ServiceManagement, UserNotifications, Combine, Foundation/Darwin
- CLI/system tooling: `/bin/ps` for top-process sampling, `kill` for terminating processes, `getifaddrs` for network stats
- Apple system apps & services: Activity Monitor (launched via `NSWorkspace`), System Events (driven by AppleScript) for UI scripting, and Notification Center for user alerts; accessibility permission is required for scripted keystrokes
