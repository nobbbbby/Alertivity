## ADDED Requirements
### Requirement: Detection supports configurable memory threshold
The app SHALL expose a memory usage percentage threshold (default 15%, clamped between 5–50%) that determines whether a process is considered high-activity for memory, persisting the value in preferences and applying it when filtering processes without altering overall status evaluation. The control SHALL sit alongside the existing CPU threshold control in the Detection settings so both thresholds are configured together.

#### Scenario: User raises memory threshold to reduce noise
- **WHEN** the user sets the memory detection threshold to 25% in Settings
- **THEN** the preference SHALL save at 25% (clamped into 5–50% if out of range), and processes SHALL only be marked high-activity for memory when they reach at least that threshold, reducing the number of memory-driven entries

#### Scenario: Detection tab shows CPU and memory thresholds together
- **WHEN** the user opens the Detection settings tab
- **THEN** the CPU threshold selector and the memory detection threshold control SHALL appear together in that section so users can adjust both rules in one place

#### Scenario: Defaults preserved for existing users
- **WHEN** the app updates and the user has not set a custom threshold
- **THEN** the memory detection threshold SHALL default to 15% so behavior remains unchanged until the user opts in to a new value
