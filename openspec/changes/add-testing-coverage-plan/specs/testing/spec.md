## ADDED Requirements
### Requirement: Test suite follows a pyramid distribution
The automated test suite SHALL adopt a pyramid distribution aligned with Apple's guidance: unit tests form the bulk of coverage and run quickly; integration tests provide a smaller layer that exercises composed components; UI tests are a thin smoke layer covering top use cases. Unit tests SHALL outnumber integration tests by at least 2:1, and UI tests SHALL be fewer than integration tests, focused on essential user journeys only.

#### Scenario: Suite composition shows unit-heavy pyramid
- **WHEN** the CI test run enumerates automated tests across unit, integration, and UI targets
- **THEN** unit tests SHALL represent the majority of executed cases, outnumbering integration tests by at least 2:1, and UI tests SHALL be fewer than integration tests and limited to smoke coverage for critical flows

### Requirement: Core logic unit tests cover status, gating, and persistence
Unit tests SHALL exercise core logic modules with measurable coverage: ActivityStatus/status-evaluation rules (thresholds, tie-breaking, auto-switch selection), notification throttling/gating, high-activity process filtering, and settings persistence. These modules SHALL maintain at least 70% line coverage when run with code coverage enabled.

#### Scenario: Coverage meets targets for core modules
- **WHEN** running `xcodebuild test` (or CI equivalent) with code coverage enabled on the unit test target
- **THEN** ActivityStatus/status-evaluation helpers, notification gating/throttling, process filtering, and settings persistence code SHALL each report at least 70% line coverage and include assertions for threshold boundaries and dwell timing

### Requirement: Integration tests verify end-to-end metric and messaging flow
Integration tests SHALL use stubbed metric providers and notification sinks to drive ActivityMonitor through elevated/critical transitions, ensuring menu messaging and notification payloads stay consistent with status evaluation and high-activity dwell rules.

#### Scenario: Metric transitions drive consistent status and messaging
- **WHEN** a stub provider feeds a sequence that crosses elevated and critical thresholds for CPU and memory with configured dwell times
- **THEN** ActivityMonitor SHALL publish the expected ActivityStatus transitions, the menu/notification messaging helpers SHALL reflect the triggering metrics, and notifications SHALL only be recorded after dwell requirements are met

### Requirement: UI smoke tests cover primary user flows
UI tests SHALL cover the primary user journeys without broad surface explosion: launching the app, opening the menu, viewing status/metric icons, toggling notification/detection settings, and confirming the app remains responsive.

#### Scenario: UI flows execute without crashes
- **WHEN** a UI test launches the app, opens the menu, and toggles notification/detection settings
- **THEN** the status and metric icons SHALL render without crashes, the toggles SHALL persist within the session, and the UI test SHALL exit cleanly to keep the smoke suite reliable
