## 1. Implementation
- [x] 1.1 Add a shared `Logger` subsystem/categories and replace the existing `NSLog`.
- [x] 1.2 Instrument metrics sampling and status evaluation with debug-only logs for successes, fallbacks, and errors/timeouts.
- [x] 1.3 Log notification send/throttle decisions, process reveal/terminate actions, and preference toggles (launch-at-login, Dock visibility, menu/notification toggles).
- [x] 1.4 Ensure logs stay in debug builds only and avoid excessive/PII-heavy details.
- [x] 1.5 Build the app to confirm logging compiles and emits in debug. (Used `xcodebuild … SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG DISABLE_PREVIEWS" ENABLE_PREVIEWS=NO` with derived data at `./DerivedData` to bypass preview macro sandbox limits.)

## 2. Validation
- [x] 2.1 Run `openspec validate add-structured-logging --strict`.
- [ ] 2.2 Manual: Launch debug build and verify logs for sampling, status changes, notifications, and process actions.
`
