## Why
TestFlight/App Store builds run inside App Sandbox, which blocks the `/bin/ps` sampling used for per-process alerts. We need to distinguish detection controls from notification triggers so process thresholds do not directly notify, and reflect build differences clearly in Settings.

## What Changes
- Add an App Store (sandboxed) vs Direct (non-sandboxed) build variant approach for process sampling.
- Restore a dedicated Detection settings tab, shown only in non-sandboxed builds.
- Move CPU/memory thresholds (and duration) into Detection for process flagging rather than notification triggers.
- Redesign notification trigger logic to fire when any metric is critical for the configured duration, with duration affecting both status and process-based notifications.
- Detect process-sampling availability at runtime and adjust per-process notifications accordingly.
- Surface a concise note near the notification toggle describing trigger conditions for the current build.

## Impact
- Affected specs: `openspec/specs/activity-status/spec.md`, `openspec/specs/settings/spec.md`
- Affected code: build settings/entitlements, `SystemMetricsProvider`, `NotificationManager`, Settings UI
