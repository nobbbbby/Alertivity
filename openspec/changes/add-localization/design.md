## Context
Alertivity currently ships user-facing strings in SwiftUI views and notification content without localization. Adding localization spans the menu bar UI, settings, and notifications and introduces new resource files.

## Goals / Non-Goals
- Goals: Localize all user-facing strings and follow the system locale with no in-app override; provide Chinese, Japanese, and French translations.
- Non-Goals: Runtime language switching inside the app; automated translation tooling.

## Decisions
- Decision: Use a String Catalog (`Localizable.xcstrings`) with standard APIs (`String(localized:)` / `NSLocalizedString`) for all user-facing text.
- Decision: Adopt language folders `zh-Hans.lproj`, `ja.lproj`, and `fr.lproj` for initial translations.

## Risks / Trade-offs
- Translation accuracy and text length may affect UI layout; mitigate via manual review of menus and settings per locale.

## Migration Plan
- Introduce base strings first, then add localized variants; verify system locale switching reflects changes.

## Open Questions
- None.
