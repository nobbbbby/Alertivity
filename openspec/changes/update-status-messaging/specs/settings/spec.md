## MODIFIED Requirements
### Requirement: Settings keep existing tabs with targeted inline guidance
The settings UI SHALL retain a concise tab structure (General, Menu Bar, Notifications) with detection controls relocated into the Notifications tab, align each tab's content to the leading edge, and place short helper notes near non-obvious controls while avoiding scattered footers. The former Detection tab SHALL be removed to keep notification-related controls co-located.

#### Scenario: Notification tab houses detection controls
- **WHEN** the user opens the Notifications tab
- **THEN** the notification options and detection controls (including high-activity thresholds/duration) SHALL appear together with their helper notes, and no separate Detection tab is present

#### Scenario: Menu-driven settings mirror section order and essential notes
- **WHEN** the user opens settings via the menu (NoticePreferencesView) instead of the system Settings window
- **THEN** the section order and helper notes for notifications and detection SHALL mirror the main Notifications tab layout; other sections may omit notes when the control is self-explanatory

### Requirement: Detection supports configurable memory threshold
The app SHALL expose a memory usage percentage threshold (default 15%, clamped between 5–50%) that determines whether a process is considered high-activity for memory, persisting the value in preferences and applying it when filtering processes without altering overall status evaluation. The control SHALL sit alongside the existing CPU threshold control within the Notifications tab so both detection thresholds are configured next to notification settings.

#### Scenario: Detection tab shows CPU and memory thresholds together
- **WHEN** the user opens the Notifications tab
- **THEN** the CPU threshold selector and the memory detection threshold control SHALL appear together in that section so users can adjust both rules in one place within the notification context
