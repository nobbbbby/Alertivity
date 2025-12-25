# Change: Compute ActivityStatus from CPU, memory, and disk

## Why
The current ActivityStatus only reflects CPU usage, so memory pressure or a nearly full disk can still surface as a "normal" system even when the menu and notifications should warn the user. We need ActivityStatus to represent overall system strain so the menu bar view and notifications stay trustworthy, and simplify the menu UI by removing redundant detail views.

## What Changes
- Evaluate ActivityStatus using the highest severity across CPU, memory, and disk thresholds instead of CPU alone, with clear per-metric thresholds and tie-breaking rules.
- Summarize the current CPU/memory/disk state in the ActivityStatus message so both the menu status row and notifications explain the overall system status.
- Surface which metric triggered the status in the menu view (status row and icon context) and keep showing the high-activity processes that caused elevated/critical states for CPU, memory, and network (disk excluded to avoid slow sampling). Keep metric icon tinting adaptive in normal state and tint only the corresponding elevated/critical metric (including network) when that metric is the high-activity trigger.
- Remove the separate MetricMenuDetailView now that the summary view covers the needed context.
- Remove the Processes metric option from menu icon/selection while keeping the high-activity process list for CPU/memory/network.

## Impact
- Affected specs: activity-status
- Affected code: ActivityStatus evaluation and messaging, ActivityMonitor metrics derivation, menu status row/icon rendering (and removal of MetricMenuDetailView), NotificationManager message composition, metric/process presentation
