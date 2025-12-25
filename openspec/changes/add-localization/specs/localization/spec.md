## ADDED Requirements
### Requirement: User-facing text is localized
The system SHALL present all user-facing strings (menu bar UI, settings, notifications, and action labels) using localized resources.

#### Scenario: Menu bar UI respects localization
- **WHEN** the system locale is set to a supported language
- **THEN** menu bar labels and metric rows display localized text

#### Scenario: Settings UI respects localization
- **WHEN** the system locale is set to a supported language
- **THEN** settings tabs, labels, and helper notes display localized text

#### Scenario: Notifications and actions respect localization
- **WHEN** the system locale is set to a supported language
- **THEN** notification titles, bodies, and action buttons display localized text

### Requirement: Supported languages include Chinese, Japanese, French, and German
The system SHALL ship localized strings for Chinese (Simplified), Japanese, French, and German.

#### Scenario: Chinese localization available
- **WHEN** the system locale is set to Chinese (Simplified)
- **THEN** the app uses the Chinese localized strings

#### Scenario: Japanese localization available
- **WHEN** the system locale is set to Japanese
- **THEN** the app uses the Japanese localized strings

#### Scenario: French localization available
- **WHEN** the system locale is set to French
- **THEN** the app uses the French localized strings

#### Scenario: German localization available
- **WHEN** the system locale is set to German
- **THEN** the app uses the German localized strings

### Requirement: Localization follows system locale
The system SHALL select localization based on the macOS system locale without an in-app language override.

#### Scenario: Locale selection uses system settings
- **WHEN** the user changes the macOS language setting
- **THEN** Alertivity reflects the new language after restart or relaunch
