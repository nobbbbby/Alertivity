# Change: Tidy Settings layout while keeping familiar tabs

## Why
The current four tabs work, but helper text sits far from controls and some spacing makes the layout feel scattered. We want to tidy copy and positioning while keeping the familiar tab structure so settings feel lighter without relearning navigation.

## What Changes
- Keep the existing General/Menu Bar/Notifications/Detection tabs but tighten layouts and keep helper notes adjacent to controls where they add value.
- Trim duplicative helper text; only non-obvious settings (like notifications and detection thresholds) keep short inline notes.
- Align section order and essential wording in `NoticePreferencesView` with the main Settings view while allowing brief, optional notes per section.
- Align each tab's content to the leading edge so form controls and helper notes start from a consistent left baseline instead of floating toward the center.

## Impact
- Affected specs: settings
- Affected code: `Alertivity/ContentView.swift` (SettingsView/NoticePreferencesView), any shared settings copy/layout helpers
