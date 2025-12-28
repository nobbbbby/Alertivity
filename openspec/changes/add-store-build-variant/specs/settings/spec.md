## ADDED Requirements
### Requirement: Settings disclose notification triggers by build
The Settings UI SHALL display a concise note near the Notifications/Detection controls describing the notification triggers for the current build (sandboxed vs non-sandboxed).

#### Scenario: App Store build explains notification limits
- **WHEN** the app is running in a sandboxed build that cannot sample processes
- **THEN** Settings SHALL show a brief note indicating notifications are based on critical metrics for the configured duration and that per-process alerts require the Direct (non-sandboxed) build

#### Scenario: Direct build describes both triggers
- **WHEN** the app can sample processes
- **THEN** Settings SHALL show a brief note indicating notifications can be triggered by critical metrics (with duration) and high-activity processes

### Requirement: Detection tab available only when process sampling works
The Settings UI SHALL display a Detection tab only when process sampling is available, and SHALL hide the Detection tab when process sampling is unavailable.

#### Scenario: Direct build shows Detection tab
- **WHEN** the app can sample processes
- **THEN** Settings SHALL show a Detection tab with CPU threshold, memory threshold, and duration controls for process flagging

#### Scenario: Sandboxed build hides Detection tab
- **WHEN** the app is running in a sandboxed build that cannot sample processes
- **THEN** Settings SHALL hide the Detection tab
