## Why
TestFlight/App Store builds run inside App Sandbox, which blocks the `/bin/ps` sampling used for per-process alerts. We need a supported path that preserves full functionality for direct downloads while providing a predictable, honest experience in sandboxed builds.

## What Changes
- Add an App Store (sandboxed) vs Direct (non-sandboxed) build variant approach for process sampling.
- Detect process-sampling availability at runtime and gracefully disable per-process flagging/notifications when unavailable.
- Surface a concise note in Settings when per-process alerts are unavailable in sandboxed builds.

## Impact
- Affected specs: `openspec/specs/activity-status/spec.md`, `openspec/specs/settings/spec.md`
- Affected code: build settings/entitlements, `SystemMetricsProvider`, `NotificationManager`, Settings UI
