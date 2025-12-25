## 1. Implementation
- [x] 1.1 Add/confirm unit, integration, and UI test targets with shared test fixtures and mock providers for metrics and notifications; use Swift Testing for new unit/integration targets where supported, and keep XCUITest for UI automation.
- [x] 1.2 Cover ActivityStatus/status-evaluation rules, notification throttling/gating, process filtering, and settings persistence with unit tests; add integration tests that flow metrics through ActivityMonitor into menu/notification presenters.
- [x] 1.3 Add UI smoke tests for launching the menu, toggling key settings (notifications/detection), and validating status/metric icons render without crashes.
- [x] 1.4 Enable coverage reporting in `xcodebuild` (or CI equivalent) and document how to run the suite locally with coverage enabled; include Swift Testing invocation guidance if it differs from XCTest.

## 2. Validation
- [x] 2.1 Run `openspec validate add-testing-coverage-plan --strict`.
- [x] 2.2 Execute test targets with coverage enabled and capture the baseline pyramid distribution (unit > integration > UI).
