# Change: Add configurable memory detection threshold

## Why
High-activity detection for memory currently uses a fixed threshold, which can flag too many or too few processes depending on workload. Letting users tune the memory detection threshold reduces noise in the high-activity list while giving power users tighter visibility.

## What Changes
- Add a user-facing control to set the memory percentage that qualifies a process as high activity (default 15%, clamped to a safe range)
- Persist the selection in preferences and surface it alongside existing detection settings next to the CPU threshold with concise helper text
- Apply the configured threshold when deciding whether a process is marked high-activity for memory; leave overall status evaluation unchanged

## Impact
- Affected specs: settings
- Affected code: settings UI (ContentView/NoticePreferencesView), SystemMetricsProvider high-activity filtering, preference defaults/clamping
