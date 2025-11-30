## ADDED Requirements
### Requirement: Structured debug logging uses Logger
Alertivity SHALL use Swift's `Logger` with a shared subsystem and scoped categories for diagnostics, emitting logs only in debug builds so release binaries stay quiet.

#### Scenario: Debug logging enabled
- **WHEN** the app runs in a debug configuration
- **THEN** logging SHALL route through `Logger` with the Alertivity subsystem/categories and SHALL not emit in release builds

### Requirement: Metrics sampling and status transitions are logged
Each sampling cycle SHALL log a concise summary (CPU, memory, disk, network, process count) and any fallback or failure reasons, and ActivityStatus transitions SHALL be logged with the triggering metric/value to aid debugging.

#### Scenario: Sampling emits summary and failures
- **WHEN** metrics are fetched or reused due to errors/timeouts
- **THEN** a debug log SHALL capture the sample time, CPU/memory/disk/network summary, whether values were reused, and any failure reasons (e.g., `ps` timeout)

#### Scenario: Status changes recorded with trigger
- **WHEN** ActivityStatus changes level or triggering metric
- **THEN** a debug log SHALL record the new status level, triggering metric/value, and prior status without listing all processes

### Requirement: Notifications and actions emit debug logs
Notification delivery decisions (sent or throttled/blocked), process actions (reveal/terminate), and preference toggles (launch-at-login, Dock/menu/notification settings) SHALL emit debug logs that include intent, outcome, and minimal context (e.g., pid/command in debug builds only).

#### Scenario: Notifications log send/throttle decisions
- **WHEN** a notification is queued or skipped because of throttling, authorization, or disabled settings
- **THEN** a debug log SHALL note the decision, trigger metric, and throttle timing window

#### Scenario: Process actions and preference toggles are logged
- **WHEN** a process reveal/terminate is requested or a launch-at-login/Dock/menu/notification preference changes
- **THEN** a debug log SHALL capture the action and outcome (including pid/command for process actions) while avoiding sensitive payloads
