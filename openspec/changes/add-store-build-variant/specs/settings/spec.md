## ADDED Requirements
### Requirement: Settings disclose process-alert availability by build
The Settings UI SHALL display a concise note near the Notifications/Detection controls when per-process alerts are unavailable due to sandbox restrictions, and SHALL omit the note when process sampling is available.

#### Scenario: App Store build explains missing process alerts
- **WHEN** the app is running in a sandboxed build that cannot sample processes
- **THEN** Settings SHALL show a brief note indicating that per-process alerts require the Direct (non-sandboxed) build

#### Scenario: Direct build omits the sandbox note
- **WHEN** the app can sample processes
- **THEN** Settings SHALL not show the sandbox availability note so the UI remains concise
