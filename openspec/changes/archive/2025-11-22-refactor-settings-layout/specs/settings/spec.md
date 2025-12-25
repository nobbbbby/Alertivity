## ADDED Requirements
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
