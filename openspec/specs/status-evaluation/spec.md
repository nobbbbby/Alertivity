# status-evaluation Specification

## Purpose
Define how metric severities are banded and combined into a global status (with tie-breaks, dwell, and auto-switch behavior) plus the shared status icon tint palette.
## Requirements
### Requirement: Per-metric severity bands
Metric severities SHALL be derived from clamped metric values using consistent bands: CPU (Normal <50%, Elevated 50–79.9%, Critical ≥80%), Memory (Normal <70%, Elevated 70–84.9%, Critical ≥85% of total), Disk throughput (Normal <20 MB/s, Elevated 20–99.9 MB/s, Critical ≥100 MB/s aggregated read+write), and Network throughput (Normal <5 MB/s, Elevated 5–19.9 MB/s, Critical ≥20 MB/s aggregated send+receive).

#### Scenario: Network elevated threshold
- **WHEN** total network throughput reaches 12 MB/s
- **THEN** the network severity is Elevated and reported in MB/s units

#### Scenario: Disk critical threshold
- **WHEN** aggregated disk throughput reaches or exceeds 100 MB/s
- **THEN** the disk severity is Critical and uses throughput-based units rather than capacity usage

### Requirement: Global status determination
Global status SHALL reflect the highest per-metric severity across CPU, memory, disk, and network; ties MUST use priority CPU > Memory > Disk > Network. Status level changes MUST require at least two consecutive samples at the new severity before switching up or down to reduce flapping.

#### Scenario: Network triggers critical status
- **WHEN** network severity is Critical and all other severities are Normal
- **THEN** the global status is Critical with the network metric as the trigger

#### Scenario: Tie favors CPU
- **WHEN** CPU and network are both Elevated and other metrics are Normal
- **THEN** the global status is Elevated with CPU as the trigger because of the tie-break priority

### Requirement: Auto-switch metric selection
Auto-switching SHALL pick the metric with the highest severity; ties MUST follow CPU > Memory > Disk > Network. Auto-switching MUST react only when a metric is Critical (Critical-only switching). The selection SHOULD remain on the current metric unless a higher-severity metric appears or the tie-break condition persists across at least two consecutive samples to avoid rapid churn.

#### Scenario: Critical outranks elevated
- **WHEN** disk becomes Critical while CPU is Elevated
- **THEN** auto-switch selects disk as the active metric

#### Scenario: Stable tie keeps priority
- **WHEN** CPU and memory stay Critical across consecutive samples
- **THEN** auto-switch continues to show CPU because it holds the tie-break priority

#### Scenario: Elevated does not trigger switching
- **WHEN** memory becomes Elevated while other metrics are Normal and auto-switch is currently showing CPU
- **THEN** auto-switch stays on CPU because switching is limited to Critical severity

### Requirement: Status icon tint palette
Status indicators SHALL use a single centralized palette: Normal uses a neutral/monochrome appearance, Elevated uses yellow, and Critical uses red; the tint applies to the status icon and per-metric indicators when they reflect overall status. Icons SHALL only change tint when status is Elevated or Critical, leaving the Normal state neutral. Metric value text SHALL remain untinted/neutral even when the icon is tinted.

#### Scenario: Elevated tint applied
- **WHEN** global status becomes Elevated
- **THEN** the status icon tint switches to the shared yellow accent while the Normal state remains neutral

#### Scenario: Value text stays neutral
- **WHEN** the status or a per-metric indicator is tinted because the status is Elevated or Critical
- **THEN** the associated metric value text remains neutral/untinted while only the icon is tinted
