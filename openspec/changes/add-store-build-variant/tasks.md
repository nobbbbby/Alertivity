## 1. Implementation
- [ ] 1.1 Add App Store vs Direct build configurations (entitlements + signing settings).
- [ ] 1.2 Add a process-sampling capability check and cache availability.
- [ ] 1.3 Redesign notification trigger logic to fire when any metric is critical (with duration), with process-based notifications only when sampling is available.
- [ ] 1.4 Gate per-process list population and process-triggered notifications on availability.
- [ ] 1.5 Restore the Detection tab for CPU/memory thresholds + duration, and hide it in sandboxed builds.
- [ ] 1.6 Move CPU/memory thresholds out of the Notifications tab into Detection.
- [ ] 1.7 Add a concise Settings note describing notification triggers and build differences.
- [ ] 1.8 Add diagnostics/logging to confirm the active capability state in debug builds.

## 2. Validation
- [ ] 2.1 Verify App Store build runs sandboxed and hides/disables per-process alerts.
- [ ] 2.2 Verify Direct build shows the Detection tab and per-process alerts/notifications.
