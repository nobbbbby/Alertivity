## Why
Alertivity is used by a global audience, and users expect the UI to respect their system language without extra configuration.

## What Changes
- Localize all user-facing strings in the menu bar UI, settings, and notifications.
- Follow the system locale with no in-app language override.
- Add initial translations for Chinese, Japanese, French, and German.
- Store localized content in a String Catalog (`Localizable.xcstrings`) instead of `Localizable.strings`.

## Impact
- Affected specs: localization
- Affected code: SwiftUI views, NotificationManager, settings labels, menu bar labels, localization resources
