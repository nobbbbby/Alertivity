## MODIFIED Requirements
### Requirement: High-activity process list excludes disk
The high-activity process list SHALL show processes causing elevated/critical states for CPU, memory, and network metrics when process sampling is available, and SHALL omit disk to avoid slow per-process storage sampling. When process sampling is unavailable (for example in sandboxed App Store builds), the list SHALL be omitted rather than displayed empty with actions.

#### Scenario: CPU and memory spikes show culprit processes when sampling is available
- **WHEN** ActivityStatus is elevated or critical due to CPU or memory and process sampling is available
- **THEN** the high-activity process list SHALL include the culprits for those metrics (if available) and SHALL not attempt to list disk-intensive processes

#### Scenario: Sandboxed build hides process list
- **WHEN** the app is running without process-sampling capability
- **THEN** the high-activity process list SHALL be hidden and no per-process actions SHALL be shown

### Requirement: Notifications fire only for actionable triggers
Notifications SHALL be delivered when any metric is critical for the configured duration, SHALL support provisional notification authorization, and SHALL skip disk-only critical status to avoid irrelevant alerts. Process-based notifications SHALL be emitted only when process sampling is available; otherwise, notifications SHALL rely solely on critical metric status.

#### Scenario: Any metric critical sends notification with metadata
- **WHEN** any metric is critical for the configured duration and notification authorization is `authorized` or `provisional`
- **THEN** a notification SHALL be delivered containing the triggering metric/value in its metadata so actions can target the culprit

#### Scenario: High-activity process triggers notification when sampling is available
- **WHEN** a high-activity process is present (CPU or memory) and process sampling is available
- **THEN** a notification SHALL be sent with process metadata while still respecting the throttle interval

#### Scenario: Sandboxed build omits process-triggered notifications
- **WHEN** process sampling is unavailable and no critical status exists
- **THEN** no process-triggered notification SHALL be delivered

#### Scenario: Disk-only critical status does not notify
- **WHEN** ActivityStatus is critical solely because disk usage is high and no high-activity processes are present
- **THEN** no notification SHALL be delivered, avoiding noise from disk-only conditions
