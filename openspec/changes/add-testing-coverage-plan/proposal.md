# Change: Add testing and coverage strategy

## Why
- Automated verification is limited to a single unit test, leaving most logic (status evaluation, notification gating, settings persistence, and menu rendering) untested and reliant on manual checks.
- There is no defined coverage target or structure for unit vs. integration vs. UI tests, making regressions hard to catch as features expand.
- We want to align with Apple's guidance on a test pyramid to prioritize fast, reliable unit coverage with targeted integration and UI cases.

## What Changes
- Introduce a testing strategy that favors a unit-test-heavy pyramid with a smaller set of integration tests and a few UI smoke tests for critical flows.
- Prefer the Swift Testing framework for new unit and integration tests (falling back to XCTest/XCUITest only where Swift Testing is unavailable, e.g., current UI automation).
- Define coverage expectations for core logic areas (status evaluation, notification throttling, process filtering, settings storage) and add reporting to track progress.
- Scaffold missing test targets/fixtures (integration/UI) and document how to run them locally and in CI so the suite becomes part of the standard workflow.

## Impact
- Affected specs: testing
- Affected code: Test targets/configuration, ActivityStatus/status evaluation helpers, NotificationManager gating logic, settings storage, ActivityMonitor/process filtering, and minimal UI flows exercised by UI tests
