## 1. Implementation
- [x] 1.1 Define per-metric severity thresholds for CPU, memory, and disk plus helper(s) on ActivityMetrics to evaluate each metric.
- [x] 1.2 Update ActivityStatus calculation and message to pick the highest-severity metric (with deterministic priority), summarize CPU/memory/disk state, and carry the triggering metric for downstream UI/notifications.
- [x] 1.3 Surface the triggering metric and severity in the menu view (status row/icon context) and keep showing high-activity processes for CPU, memory, and network (disk excluded to avoid slow sampling).
- [x] 1.4 Keep metric icon tinting adaptive when normal and tint only the elevated/critical triggering metric (including network) while preserving untinted metric values.
- [x] 1.5 Remove MetricMenuDetailView from the menu UI and ensure the summary view still exposes the required information.
- [x] 1.6 Update NotificationManager messages and metadata to include the triggering metric and values when alerts fire.
- [x] 1.7 Remove the Processes metric option from menu icon/selection and clean up related UI/state, while retaining the high-activity process list for CPU/memory/network.
- [x] 1.8 Manually verify status transitions for CPU-only, memory-only, disk-only, and combined spikes, including placeholder/no-data states, and confirm menu icon tinting matches elevated/critical triggers.
