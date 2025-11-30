## MODIFIED Requirements
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
