## MODIFIED Requirements
### Requirement: ActivityStatus message summarizes CPU, memory, and disk state
The ActivityStatus message SHALL concisely summarize current CPU, memory, and disk utilization so the menu status row and notifications share a consistent multi-metric explanation. Titles SHALL stay concise (e.g., “Critical CPU; Memory Elevated” in the menu or “Critical CPU; memory elevated” in notifications), omit numeric values, and avoid duplicating wording already present in the summary/body. The menu summary SHALL describe the thresholds/metrics that triggered the state level using threshold values (not live per-metric readings): single-metric summaries use full sentences (“CPU activity exceeded the elevated threshold, reaching a usage of more than 50%.”; “Disk activity exceeded the critical threshold, reaching an aggregated rate of ≥120 MB/s.”), while multi-metric summaries list per-metric “over” phrases with explicit `(critical)`/`(elevated)` labels (e.g., “CPU usage over 80% (critical), and Memory usage over 70% (elevated).”). The notification body SHALL list per-metric percentages/values with `(crit)`/`(elev)` labels consistent with the title wording and severity ordering. When more than one metric is elevated or critical, the status title/leading summary SHALL explicitly convey concurrent activity rather than only naming the single trigger, and repeated metrics at the same level SHALL collapse to “Multiple metrics critical/elevated” (menu uses title case, notification uses sentence case). When both elevated and critical metrics are present, the summary SHALL distinguish which metrics are critical versus elevated rather than flattening to a single severity.

#### Scenario: Message shows multi-metric summary for critical status
- **WHEN** ActivityStatus is `critical` due to any metric
- **THEN** the status message SHALL mention the triggering metric and include CPU, memory, and disk percentages with crit/elev labels in the notification summary, and when multiple metrics are elevated/critical the title SHALL reflect concurrent activity instead of only naming one metric

#### Scenario: Title reflects concurrent elevated metrics
- **WHEN** CPU and memory are both Elevated while disk and network are Normal
- **THEN** the status title/leading summary SHALL indicate multiple metrics are elevated (e.g., "Multiple Metrics Elevated" in the menu, "Multiple metrics elevated" in notifications) and the notification body SHALL list CPU and memory percentages

#### Scenario: Title reflects concurrent critical metrics concisely
- **WHEN** CPU and memory are both Critical while disk and network are Normal
- **THEN** the status title/leading summary SHALL indicate multiple metrics are critical using concise wording comparable to the elevated pattern (e.g., "Multiple Metrics Critical" in the menu, "Multiple metrics critical" in notifications) without expanding into per-metric numbers in the menu summary

#### Scenario: Summary differentiates mixed critical and elevated metrics
- **WHEN** CPU is Critical while Memory is Elevated and other metrics are Normal
- **THEN** the summary/title SHALL make the mixed severities clear (e.g., "Critical CPU; Memory Elevated" in the menu and "Critical CPU; memory elevated" in notifications) instead of collapsing them into a single severity, and the notification body SHALL list CPU and memory percentages

#### Scenario: Menu summary omits duplicated metric details
- **WHEN** the user opens the menu and metrics are elevated or critical
- **THEN** the status summary row SHALL avoid repeating per-metric numeric details already shown elsewhere in the menu, keeping only concise threshold rationale with threshold values (not live readings), while notifications SHALL list each non-normal metric with per-metric percentages/values and crit/elev labels

#### Scenario: Summary explains trigger thresholds concisely
- **WHEN** the system transitions to Elevated or Critical
- **THEN** the title SHALL remain concise without repeating the body wording or adding numeric values, the menu summary SHALL describe the triggering metric and its threshold rationale including threshold values (not live readings), and the notification body SHALL list each non-normal metric with its value/percentage and a matching crit/elev label so severity phrasing stays consistent across elevated and critical states

### Requirement: Notifications fire only for actionable triggers
Notifications SHALL be delivered when CPU, memory, or disk is Critical and has satisfied the configured high-activity duration, or when there are high-activity processes; they SHALL support provisional notification authorization. Disk critical notifications SHALL include disk throughput/value metadata, and notifications triggered by high-activity processes SHALL omit the generic summary body, relying on the process metadata/subtitle instead while keeping actions available.

#### Scenario: CPU, memory, or disk critical after dwell sends notification with metadata
- **WHEN** ActivityStatus is critical due to CPU, memory, or disk and the critical condition has persisted for at least the configured high-activity duration with notification authorization `authorized` or `provisional`
- **THEN** a notification SHALL be delivered containing the triggering metric/value in its metadata so actions can target the culprit

#### Scenario: Critical severity without dwell does not notify
- **WHEN** CPU, memory, or disk becomes critical but the critical condition has not yet met the configured high-activity duration
- **THEN** no notification SHALL be delivered until the dwell condition is satisfied, avoiding premature alerts

#### Scenario: High-activity process notification omits summary body
- **WHEN** a high-activity process is present (CPU or memory) regardless of disk severity and a notification is sent for that process
- **THEN** the notification SHALL include process metadata and actions, omit the generic status summary body, and provide a metric-specific description (e.g., CPU high or Memory high) so the culprit reason is explicit

#### Scenario: Disk critical sends notification after dwell
- **WHEN** ActivityStatus is critical solely because disk throughput is high, the condition meets the configured high-activity duration, and notification authorization is `authorized` or `provisional`
- **THEN** a notification SHALL be delivered with disk metadata, even if no high-activity processes are present

### Requirement: High-activity process list emphasizes triggering metric
The high-activity process list SHALL highlight whether CPU or Memory triggered inclusion by emphasizing the corresponding metric, while still showing both CPU and memory values.

#### Scenario: CPU-triggered process is emphasized
- **WHEN** a process enters the high-activity list because its CPU exceeds the configured threshold
- **THEN** the CPU value SHALL be emphasized (e.g., bold) in the menu list while Memory remains regular weight

#### Scenario: Memory-triggered process is emphasized
- **WHEN** a process enters the high-activity list because its memory exceeds the configured threshold
- **THEN** the Memory value SHALL be emphasized (e.g., bold) in the menu list while CPU remains regular weight

#### Scenario: Both metrics triggered
- **WHEN** a process meets both CPU and memory thresholds
- **THEN** both CPU and Memory values SHALL be emphasized in the menu list and the notification description SHALL mention both metrics
