# Change: Update status level schema

## Why
Global status should consider network alongside CPU, memory, and disk, and the UI should use a single palette and consistent rules for tinting. Auto-switching should remain Critical-only so it only flips when a metric crosses the highest severity, while still honoring priority order for ties.

## What Changes
- Include network in the global status decision, selecting the highest-severity metric with a deterministic priority (CPU > Memory > Disk > Network) and add light hysteresis to avoid flapping.
- Define per-metric severity bands (CPU/memory/disk/network) and make auto-switch follow the same severity-first + priority rule with an optional dwell period while remaining Critical-only.
- Centralize status colors (green/yellow/red + neutral) and apply tinting only on elevated/critical for the status icon/metric indicators.

## Impact
- Affected specs: status-evaluation
- Affected code: ActivityStatus logic, per-metric severity thresholds (ActivityMetrics), menu/status icon color usage
