# disk-metrics Specification

## Purpose
TBD - created by archiving change update-disk-metric-throughput. Update Purpose after archive.
## Requirements
### Requirement: Disk IO Throughput Metric
Disk activity SHALL be reported using data IO throughput that aligns with Activity Monitor's disk read/write reporting rather than disk capacity usage.

#### Scenario: Throughput sampled per interval
- **WHEN** the metrics sampler runs
- **THEN** it computes bytes read per second and bytes written per second from cumulative OS counters over the sampling interval
- **AND** it provides both per-direction values and an aggregated throughput total in MB/s for the disk metric

#### Scenario: Matches Activity Monitor readings
- **WHEN** the app samples disk IO while Activity Monitor shows Data read/sec and Data written/sec
- **THEN** the reported read and write throughput values stay within expected sampling variance of Activity Monitor's values

### Requirement: Throughput-based disk severity
Disk severity and busiest-metric selection SHALL be derived from aggregated disk IO throughput rather than disk capacity usage.

#### Scenario: Auto-switch uses throughput thresholds
- **WHEN** the auto-switch logic or disk severity calculation runs
- **THEN** it evaluates the aggregated read + write throughput (MB/s) against throughput-based thresholds and displays the value with throughput units

### Requirement: Disk menu bar icon layout
The disk metric's menu bar icon SHALL use the same custom-rendered layout approach as the network indicator because vertical stacking is unavailable in the menu bar.

#### Scenario: Disk icon avoids VStack via custom rendering
- **WHEN** the disk metric is displayed in the menu bar
- **THEN** its icon and value are rendered using a custom layout (like the network indicator) that does not rely on a VStack

