## ADDED Requirements
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
