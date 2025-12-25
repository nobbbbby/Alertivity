# Change: Fix settings responsiveness for launch-at-login and Dock visibility

## Why
Users report the `Launch at login` toggle only takes effect after the next launch and `Hide app icon in Dock` fails on macOS 15.7. These reduce trust in settings and make the app feel unreliable.

## What Changes
- Ensure SMAppService registration/unregistration happens immediately when the toggle flips and the stored preference stays in sync with the real status.
- Update Dock visibility handling to reliably hide/show the icon on macOS 15.7 while respecting window visibility rules.
- Add guardrails/fallbacks so transient failures reuse the current state instead of leaving the app in limbo.

## Impact
- Affected specs: settings
- Affected code: `Alertivity/AlertivityApp.swift` (launch-at-login, Dock visibility), related settings binders/UI if needed
