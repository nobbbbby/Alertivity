# StoreKit Cloud diagnostics

`ci_post_xcodebuild.sh` records read-only session metadata and filtered StoreKit
service messages after test execution. Its output appears in the Cloud custom
script log; arbitrary files created by custom scripts are not downloadable
artifacts. It does not restart services, clear caches, change accounts, or alter
the test action's exit status. Unified-log private-data collection is not enabled.

The **Alertivity StoreKit Probe** scheme selects the single async XCTest in
`StoreKitCloudProbe.swift`. Its test plan enables `ALERTIVITY_STOREKIT_PROBE=1`;
normal schemes skip that probe. The test loads the bundled local configuration,
calls StoreKit directly, verifies and finishes the transaction, and logs app
activation and on-screen window owners if the purchase remains pending. Window
titles and transaction/account identifiers are not recorded.

This probe uses the existing non-sandboxed app test host, but does not invoke
`ProStore` or run the other suites. A failure isolates the issue from those test
bodies; it does not by itself exclude app-host startup behavior.

Run locally:

```sh
xcodebuild test -project Alertivity.xcodeproj \
  -scheme 'Alertivity StoreKit Probe' -destination 'platform=macOS'
```

Run the same scheme as a separate manual Cloud test action. Keep the regular PR
checks unchanged. A diagnostic timeout remains a failure, not a skipped or
successful purchase test.
