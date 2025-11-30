# Change: Add structured debug logging

## Why
Diagnostics are currently limited to a single `NSLog` call, making it hard to see sampling issues, status transitions, notification decisions, or process actions during development. Structured debug logging will speed up troubleshooting without shipping noisy release logs.

## What Changes
- Introduce `Logger` with a shared subsystem/categories and remove the legacy `NSLog`.
- Add debug-only logs for metrics sampling outcomes, ActivityStatus transitions, and launch-at-login/Dock/menu preference effects.
- Log notification send/throttle decisions and process actions (reveal/terminate) with minimal, non-sensitive context.

## Impact
- Affected specs: logging
- Affected code: `AlertivityApp`, `ActivityMonitor`, `SystemMetricsProvider`, `NotificationManager`, `ProcessActions`, and related helpers
