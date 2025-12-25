# Change: Redesign disk metric to use IO throughput

## Why
Disk usage percentage does not reflect real-time disk pressure; we need a disk metric that matches macOS Activity Monitor by reporting data IO throughput so users see active disk load.

## What Changes
- Measure the disk metric using data read/write throughput (MB/s) consistent with Activity Monitor instead of disk capacity usage
- Update status/auto-switch logic and UI to surface throughput values and severity derived from aggregated read+write throughput
- Align any disk summaries and notifications to the throughput-based values
- Render the disk metric icon in the menu bar using the same no-VStack approach as the network indicator (custom rendered layout)

## Impact
- Affected specs: disk-metrics
- Affected code: SystemMetricsProvider disk sampler, ActivityMetrics/ActivityStatus derivation, disk rows in menu/status views, related settings and thresholds
