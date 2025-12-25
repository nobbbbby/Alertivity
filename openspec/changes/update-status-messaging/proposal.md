# Change: Update status messaging and notification gating

## Why
- The status summary/title only names a single triggering metric, even when multiple metrics are elevated or critical, which hides concurrent activity.
- Critical notifications can fire without considering the configured high-activity duration, leading to noisy alerts.
- Process-triggered notifications reuse the generic summary body, duplicating information already present in the process metadata/subtitle.

## What Changes
- Make the status summary/title multi-metric aware so it explicitly signals when multiple metrics are elevated or critical in the menu and notifications.
- Require critical notification delivery to respect the configured high-activity duration before alerting.
- Adjust process-driven notifications to omit the generic summary body while keeping process context and actions intact.
- Move detection settings into the Notifications tab since they only affect notification behavior, keeping related controls together.
- Emphasize which metric (CPU or Memory) flagged high-activity processes: bold the matching metric in the menu list and include a metric-specific description in process-triggered notifications.

## Impact
- Affected specs: activity-status, settings (layout changes)
- Affected code: ActivityStatus title/message helpers, notification gating logic (ActivityMonitor/NotificationManager), process-notification payload construction and messaging, settings UI layout for detection controls, high-activity process presentation.
