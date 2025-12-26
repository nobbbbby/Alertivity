## 1. Implementation
- [ ] 1.1 Add App Store vs Direct build configurations (entitlements + signing settings).
- [ ] 1.2 Add a process-sampling capability check and cache availability.
- [ ] 1.3 Gate per-process list population and process-triggered notifications on availability.
- [ ] 1.4 Add a Settings note explaining per-process alert availability in sandboxed builds.
- [ ] 1.5 Add diagnostics/logging to confirm the active capability state in debug builds.

## 2. Validation
- [ ] 2.1 Verify App Store build runs sandboxed and hides/disables per-process alerts.
- [ ] 2.2 Verify Direct build shows per-process alerts and notifications.
