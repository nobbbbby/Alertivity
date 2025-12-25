# activity-status Specification

## Purpose
TBD - created by archiving change update-activity-status-multi-metric. Update Purpose after archive.
## Requirements
### Requirement: ActivityStatus reflects highest-severity CPU/memory/disk metric
ActivityStatus SHALL evaluate CPU, memory, and disk utilization and set the overall status to the highest severity among those metrics using consistent thresholds (CPU normal <50%, elevated 50–79%, critical ≥80%; memory normal <70%, elevated 70–84%, critical ≥85% of total; disk normal <85%, elevated 85–94%, critical ≥95% of total). When multiple metrics share the same severity, CPU takes precedence, then memory, then disk.

#### Scenario: CPU drives critical while other metrics are normal
- **WHEN** CPU usage reaches 80% or higher while memory usage is below 70% and disk usage is below 85%
- **THEN** ActivityStatus SHALL be `critical` with CPU recorded as the triggering metric and both the menu and notifications SHALL reflect critical state

#### Scenario: Memory elevates status when CPU is calm
- **WHEN** memory usage reaches 70–84% of total while CPU is below 50% and disk is below 85%
- **THEN** ActivityStatus SHALL be `elevated` with memory recorded as the triggering metric and the menu status row SHALL show that memory pressure elevated the status

#### Scenario: Disk occupancy can push status to critical even with moderate CPU
- **WHEN** disk usage reaches 95% of total while CPU is between 50–79% and memory is below 70%
- **THEN** ActivityStatus SHALL be `critical` with disk recorded as the triggering metric and the status SHALL override CPU's elevated severity because disk is critical

### Requirement: ActivityStatus message summarizes CPU, memory, and disk state
The ActivityStatus message SHALL concisely summarize current CPU, memory, and disk utilization so the menu status row and notifications share a consistent multi-metric explanation. Menu titles use title case (e.g., "Multiple Metrics Elevated"), notification titles use sentence case (e.g., "Multiple metrics elevated"), and repeated metrics at the same level SHALL collapse to "Multiple metrics critical/elevated." Menu summaries use threshold-based sentences for single metrics and concise "over" clauses with "(critical)/(elevated)" tags for multi-metric states, while notification bodies list live values with "(crit)/(elev)" tags in severity order.

#### Scenario: Message shows multi-metric summary for critical status
- **WHEN** ActivityStatus is `critical` due to any metric
- **THEN** the status message SHALL mention the triggering metric and include CPU, memory, and disk percentages in the notification body, while the menu summary SHALL use threshold-based phrasing rather than live readings

### Requirement: Status reason appears in menu view and notifications
The UI and notifications SHALL surface which metric triggered the current ActivityStatus, reusing the same triggering metric chosen by the evaluator so users understand why the state changed.

#### Scenario: Menu status row names the triggering metric
- **WHEN** ActivityStatus is elevated or critical due to a specific metric (CPU, memory, or disk)
- **THEN** the menu status row SHALL identify that metric (e.g., "Memory pressure elevated" or similar wording) and the overall status icon/context SHALL correspond to that severity

#### Scenario: Notifications include the triggering metric and value
- **WHEN** a notification is sent for a critical status
- **THEN** the notification title/body SHALL mention the triggering metric and its value (CPU %, memory %, or disk % full), and the metadata SHALL include the same metric so actions/links remain consistent with the surfaced reason

### Requirement: High-activity process list excludes disk
The high-activity process list SHALL show processes causing elevated/critical states for CPU, memory, and network metrics, and SHALL omit disk to avoid slow per-process storage sampling.

#### Scenario: CPU and memory spikes show culprit processes
- **WHEN** ActivityStatus is elevated or critical due to CPU or memory
- **THEN** the high-activity process list SHALL include the culprits for those metrics (if available) and SHALL not attempt to list disk-intensive processes

### Requirement: MetricMenuDetailView is removed
The menu UI SHALL rely on the compact summary view and SHALL remove the separate MetricMenuDetailView component so only the summary presentation remains.

#### Scenario: Menu shows summary without detail view
- **WHEN** the user opens the menu
- **THEN** the menu SHALL present the summary/status view without rendering MetricMenuDetailView or an equivalent detail panel

### Requirement: Processes metric option is removed
The menu icon selection SHALL no longer offer a Processes metric option, while the high-activity process list remains available for CPU, memory, and network contexts.

#### Scenario: Processes icon option not selectable
- **WHEN** the user configures the menu icon
- **THEN** the Processes metric SHALL not appear as a selectable icon type, and existing preferences shall fall back to a supported option without error

### Requirement: Metric icon tint matches triggering severity
Metric menu icons SHALL use the adaptive system color when their metric is normal and SHALL tint only the metric that is elevated or critical (including network) with the status accent color, while metric values remain untinted.

#### Scenario: Normal metrics stay adaptive
- **WHEN** the network metric remains below the high-activity threshold (normal severity)
- **THEN** the network icon SHALL render with the adaptive system tint (light/dark) and the download/upload text SHALL remain untinted

#### Scenario: Triggering metric tints when elevated or critical
- **WHEN** a metric (CPU, memory, disk, or network) is elevated or critical and is the triggering metric for ActivityStatus
- **THEN** that metric's menu icon SHALL be tinted with the status accent color while the metric value text remains untinted and other normal metrics stay adaptive

### Requirement: Notifications fire only for actionable triggers
Notifications SHALL be delivered only for critical CPU or memory status or when there are high-activity processes, SHALL support provisional notification authorization, and SHALL skip disk-only critical status to avoid irrelevant alerts.

#### Scenario: CPU or memory critical sends notification with metadata
- **WHEN** ActivityStatus is critical due to CPU or memory and notification authorization is `authorized` or `provisional`
- **THEN** a notification SHALL be delivered containing the triggering metric/value in its metadata so actions can target the culprit

#### Scenario: High-activity process triggers notification even if disk is benign
- **WHEN** a high-activity process is present (CPU or memory) regardless of disk severity
- **THEN** a notification SHALL be sent with process metadata while still respecting the throttle interval

#### Scenario: Disk-only critical status does not notify
- **WHEN** ActivityStatus is critical solely because disk usage is high and no high-activity processes are present
- **THEN** no notification SHALL be delivered, avoiding noise from disk-only conditions
