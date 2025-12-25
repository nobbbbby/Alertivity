# settings Specification

## Purpose
Define how the Settings surfaces configure app behavior (tabs/layout, launch-at-login and Dock visibility, menu icon auto-switching, and detection thresholds) so the UI and stored preferences stay consistent with expected behavior.
## Requirements
### Requirement: Settings keep existing tabs with targeted inline guidance
The settings UI SHALL retain the current tab structure (General, Menu Bar, Notifications, Detection), align each tab's content to the leading edge, and place short helper notes near non-obvious controls while avoiding scattered footers.

#### Scenario: Notes appear only where they add clarity
- **WHEN** the user views notification or detection controls (or other non-obvious settings)
- **THEN** a brief note SHALL appear adjacent to those controls with platform-appropriate brevity, while straightforward toggles may omit helper text

#### Scenario: Menu-driven settings mirror section order and essential notes
- **WHEN** the user opens settings via the menu (NoticePreferencesView) instead of the system Settings window
- **THEN** the section order and helper notes for alerts/detection SHALL mirror the main Settings view; other sections may omit notes when the control is self-explanatory

#### Scenario: Tab content aligns to a consistent leading edge
- **WHEN** the user switches between any Settings tab (General, Menu Bar, Notifications, Detection)
- **THEN** the form sections and helper notes SHALL share a consistent leading alignment rather than floating toward the center, keeping controls anchored to the left baseline

### Requirement: Launch at login toggle applies immediately
The app SHALL apply launch-at-login changes without waiting for a relaunch and keep preferences in sync with the actual `SMAppService.mainApp.status`.

#### Scenario: Enable launch at login during session
- **WHEN** the user turns on Launch at login while the app is running
- **THEN** the app SHALL register with `SMAppService.mainApp` immediately, reflect the enabled state in settings, and not require a restart

#### Scenario: Disable launch at login during session
- **WHEN** the user turns off Launch at login while the app is running
- **THEN** the app SHALL unregister immediately, persist the disabled state, and if registration state cannot be changed SHALL re-read the status and update the preference/UI to match reality

### Requirement: Dock icon visibility matches preference on macOS 15.7+
The app SHALL honor the Dock visibility preference on macOS 15.7+ while preserving menu bar availability and proper activation when windows are visible.

#### Scenario: Hide Dock icon with no visible windows
- **WHEN** the user enables Hide app icon in Dock on macOS 15.7+ and no regular windows are visible
- **THEN** the app SHALL switch to accessory activation policy so the Dock icon hides while keeping the menu bar item available

#### Scenario: Reveal Dock icon when windows are visible or preference is disabled
- **WHEN** a regular window becomes visible or the user disables Hide app icon in Dock
- **THEN** the app SHALL switch to regular activation policy and re-activate as needed so the Dock icon reappears

#### Scenario: Menu bar utility windows do not block Dock hiding
- **WHEN** only menu bar extra windows or other non-user-facing windows are visible
- **THEN** the app SHALL continue to treat the Dock icon as hideable so accessory activation remains effective on macOS 15.7+

### Requirement: Auto switch menu icon surfaces highest-activity metric
The settings SHALL provide an Auto switch option for the menu bar indicator that automatically selects the currently highest-activity metric while keeping icon visibility controls (Show metric icon, Only show on high activity) coherent with auto switching and presenting a helper note beside the Auto switch control.

#### Scenario: Highest activity metric appears with deterministic priority
- **WHEN** Auto switch is enabled and multiple metrics (CPU, memory, network, disk) are simultaneously in a high-activity state
- **THEN** the menu bar indicator SHALL show the metric with highest priority in the order CPU, Memory, Network, Disk and display that metric's icon/value

#### Scenario: Fallback to chosen icon when activity normalizes
- **WHEN** Auto switch is enabled and no metric is currently in a high-activity state
- **THEN** the menu bar indicator SHALL show the default icon type the user selected (status or a specific metric) without auto rotation, using the label “Default icon type” in the settings

#### Scenario: Show metric icon enforced while auto switching
- **WHEN** the user turns on Auto switch and the Show metric icon toggle is off
- **THEN** the Show metric icon option SHALL be turned on automatically and remain enabled (non-disableable) until Auto switch is turned off

#### Scenario: Only show on high activity stays available with Auto switch
- **WHEN** the user enables Auto switch
- **THEN** the Only show on high activity toggle SHALL remain available for use alongside Auto switch so the indicator can still be limited to high-activity periods if the user chooses

#### Scenario: Helper note accompanies Auto switch
- **WHEN** the user views the Auto switch control in settings
- **THEN** a concise helper note SHALL appear near the control describing that Auto switch shows the highest-activity metric and otherwise uses the Default icon type; the Default icon type selector SHALL appear second in the control order to keep the note adjacent and the fallback obvious

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
