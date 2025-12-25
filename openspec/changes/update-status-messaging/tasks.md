## 1. Proposal
- [x] 1.1 Review current ActivityStatus messaging/notification behavior and relevant specs for baseline
- [x] 1.2 Draft and validate spec deltas for activity-status covering multi-metric titles, dwell-based critical notifications, and process notification body changes
- [x] 1.3 Incorporate metric-specific emphasis for high-activity processes into proposal/spec

## 2. Implementation
- [x] 2.1 Update ActivityStatus title/message logic to surface concurrent elevated/critical metrics
- [x] 2.2 Gate critical notification delivery on the configured high-activity duration and align detection hooks
- [x] 2.3 Remove/adjust summary body for process-triggered notifications while preserving process metadata and actions
- [x] 2.4 Relocate detection controls into the Notifications tab and adjust layout/notes accordingly
- [x] 2.5 Run/record validation (build or previews) to confirm menu, notifications, and settings layout match updated specs
- [x] 2.6 Emphasize triggering metric in process list and notification description
