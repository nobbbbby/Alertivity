# Developer guide

## Build

Use a current stable Xcode compatible with the project’s assets and host macOS. The documentation was checked with Xcode 27.0; older versions have not been verified. See [Getting started](https://github.com/nobbbbby/Alertivity/wiki/Getting-Started#choose-a-build) for platform requirements and target differences.

```sh
git clone https://github.com/nobbbbby/Alertivity.git
cd Alertivity
open Alertivity.xcodeproj
```

Select **Alertivity (Non-sandboxed)** for process features or **Alertivity** for the sandboxed target. Under **Signing & Capabilities**, select your Apple development team. Add your account through **Xcode → Settings → Accounts** if needed, then Run. To build from Terminal:

```sh
xcodebuild \
  -project Alertivity.xcodeproj \
  -scheme 'Alertivity (Non-sandboxed)' \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

For Terminal builds, add `DEVELOPMENT_TEAM=YOUR_TEAM_ID` to select your team.

## Tests

Run the Swift Testing and UI suites with:

```sh
xcodebuild \
  -project Alertivity.xcodeproj \
  -scheme 'Alertivity (Non-sandboxed)' \
  -testPlan Alertivity \
  -destination 'platform=macOS' \
  test
```

UI tests isolate app preferences and skip login registration. Onboarding coverage checks persisted outcomes, preference preservation, permission changes, explicit style application, and replay. Optional screenshots require `ALERTIVITY_CAPTURE_ONBOARDING=1` in the test-runner environment; capture can fail on secondary displays.

For layout review, open `Alertivity/Features/Onboarding/OnboardingLayoutPreviews.swift` in Xcode Canvas. Its sample readings do not start monitoring or change preferences. Equal-width preview columns keep the center divider fixed as values change.

## Project structure

The project navigator follows the folders on disk using Xcode synchronized folders. Both app targets share `Alertivity/`; each test folder belongs only to its matching test target. Adding a Swift file inside one of these folders automatically includes it in that target.

| Folder | Contents |
| --- | --- |
| `Alertivity/App/` | App entry point, scenes, menu commands, and login registration |
| `Alertivity/Features/` | Menu bar, settings, onboarding, Pro purchases, and review flows |
| `Alertivity/Monitoring/` | Sampling, readings, thresholds, status transitions, and process actions |
| `Alertivity/Notifications/` | Alert delivery, shared cooldown, and permission UI |
| `Alertivity/Shared/` | Logging and localization helpers |
| `Alertivity/Resources/` | App icon, asset catalog, and string catalogs |
| `Alertivity/Preview Content/` | Development-only preview assets |
| `AlertivityTests/` | Unit and integration tests by feature, with shared fixtures in `Support/` |
| `AlertivityUITests/` | UI automation |
| `Configuration/` | Shared Info.plist and each app target's signing entitlements |
| `StoreKit/` | Local purchase fixture |

`Configuration/` and `StoreKit/` are visible in Xcode. Build settings reference the plist and entitlements explicitly. The StoreKit fixture is copied only into the unit-test bundle; schemes also reference it for local debugging. Keep development fixtures outside `Alertivity/` so folder synchronization does not add them to shipped resources. Target names, bundle identifiers, and the root `Alertivity.xctestplan` remain stable.

## Window and permission handling

Onboarding stores `pending`, `completed`, or `skipped`. Closing a pending guide records `skipped`; replay never resets preferences. An in-memory replay flag distinguishes a Help menu action from automatic scene creation. Window restoration is disabled for the guide, and an unsolicited restored guide dismisses before activation. The launch check runs once per process because SwiftUI can recreate menu labels.

Notification requests are serialized and refresh authorization first. Permission UI refreshes on app activation after external changes. Settings opens through native SwiftUI APIs; login registration uses `SMAppService`. System Settings opens by application bundle identifier with navigation guidance, avoiding undocumented pane URLs.

Use the existing OSLog categories for state changes and errors. Do not log sensitive process data. See [Design decisions](https://github.com/nobbbbby/Alertivity/wiki/Design-Decisions) and [Editing the wiki](https://github.com/nobbbbby/Alertivity/wiki/Maintaining-the-Wiki).

## Localization

See [Localization](https://github.com/nobbbbby/Alertivity/wiki/Localization) for catalog ownership, language coverage, format placeholders, and validation. Update translations alongside changes to visible text, notification messages, tooltips, and accessibility labels.

## Auto Switch priorities

`SettingsStore.menuIconAutoSwitchPriority` persists the metric order. `MetricMenuSelection.normalizedAutoSwitchPriority` removes duplicates and appends missing metrics in the default CPU → Memory → Disk → Network order. The priority editor preserves each metric once and provides localized raise/lower accessibility labels. Reset Priority restores the default order.

The menu bar controller selects the first Critical metric in that order after two matching samples. Reordering affects only Auto Switch, not the overall status, summary ordering, or notification trigger priority. Priority and metric-icon help remain available in the free App Store build.

## Application commands

`App/AlertivityCommands.swift` owns custom application menu commands. Native app
preferences remain under Alertivity → Settings; the metrics panel retains its
Open Settings shortcut. Help groups Getting Started separately from Write Review
and Send Feedback. Debug → Activity Simulator is compiled only in Debug. Existing
localized review, onboarding, and feedback actions are shared with their other
entry points.

The Debug UI-test harness removes its scene commands, so SwiftUI does not expose
New Alertivity UI test window in the File menu. Test launches still use the harness.

## Menu summaries

`ActivityStatus.menuSummary(for:)` formats the thresholds reached by the current readings. Notification wording uses separate strings. Localized list formatting and line wrapping handle multiple affected metrics. Formatting runs on every refresh and emits no logs; sampling and alert delivery use their existing log categories.

## Debug screenshot capture

Run either app scheme in **Debug** and choose **Debug → Activity Simulator…** from
Alertivity's application menu bar. If the app is running without a Dock icon,
open Settings from its metrics panel first to bring Alertivity's menus forward.
The separate utility window offers Normal and Elevated/Critical presets for CPU,
memory, disk, and network; the metrics panel contains no capture controls.
The selected snapshot freezes the panel and menu bar display using the effective
thresholds. Auto Switch resolves a Critical snapshot immediately. The indicator
stays visible during capture even when the saved visibility settings would hide
it. Live monitoring continues independently; presets never enter automatic alert
delivery or change saved settings. **Return to Live** (or the Live readings preset)
restores the usual display, and restarting the app also resets the selection.
Closing the Activity Simulator window keeps the preset active for clean captures;
reopening the command returns to the same singleton window and selection.

**Send preview notification** sends a real macOS banner for the selected simulated
preset after three seconds. Grant notification permission when asked; if permission
was denied, enable it in System Settings → Notifications. Focus and macOS banner
settings still govern presentation. Preview requests bypass the normal duration
and cooldown without changing either one's state. System previews have no process actions.
Move or close the Activity Simulator window after scheduling to capture the banner.
The notification controls stay in that window, so no timed hiding is needed.

In the Debug non-sandboxed build, **Alert type** also offers Process CPU, Process
memory, and Process CPU + memory. These use a sample Xcode process and the same
localized process message formatter and native notification actions as live
detection. Process previews can be sent while the display remains on live readings.
Their payload deliberately omits the PID and command required by the response
handler, so Show in Activity Monitor, Ignore, and Force Quit do nothing for preview
banners, including if the app is later relaunched in Release. Process fixtures never
enter the metrics panel or monitoring pipeline. The App Store build keeps system
notification previews only, matching its supported feature set.

These English-only development controls, snapshot fixtures, and preview notification
API are compiled only under `#if DEBUG` and are absent from Release builds. Preset
changes and notification scheduling/errors use the existing metrics/notifications
log categories.

## App Store Pro configuration (AL-79)

The sandboxed app target defines `APP_STORE` in both Debug and Release. The non-sandboxed
target does not. This explicit build distinction controls monetization; runtime failures of
process sampling must never change purchase requirements.

`SettingsStore.monitoringConfiguration` resolves saved preferences into the effective Free/Pro
configuration used by monitoring and notifications. UI lock states alone are insufficient.
StoreKit-verified access enables the saved configuration; lack of access uses fixed defaults.
Access is rechecked on launch, app activation, restore, and transaction updates, without trusting
a Boolean in UserDefaults. Existing users' saved custom values survive the transition to Free,
refunds, and subsequent restoration. All source-build features remain available without StoreKit.

Before release, create a **non-consumable** App Store Connect product matching
`ProStore.productID` (`com.Nobby.Alertivity.pro`), choose its price and availability, provide its
localized metadata and review information, and validate the purchase flow in Apple's sandbox.
The app uses the product's localized `displayPrice`; no production price is hardcoded. Product
configuration and App Store approval are release requirements. The app reports unavailable
purchase options if the product is not returned, while still allowing restoration.

`StoreKit/Alertivity.storekit` is a local test fixture. Its $0.99 price is a test value, not a pricing
decision. `NativeProPurchaseTests` uses `SKTestSession` with this fixture to exercise the native
StoreKit adapter through purchase, restore, relaunch, and refund without real charges. The
non-sandboxed host runs those tests with an explicitly injected App Store distribution. Mocked
purchase tests cover pending, cancellation, failures, updates, and the absence of StoreKit calls
from the source build. The sandboxed `Alertivity` scheme already selects the fixture under
**Run → Options → StoreKit Configuration** for local debugging. Select **None** there when
testing real App Store Connect products in Apple’s sandbox. The fixture is also visible in the
project navigator and is not included in the app’s resources or Archive configuration.

Referral rewards are not implemented; their qualification rules and platform feasibility remain
part of AL-74.

### Local StoreKit regression coverage

Run `AlertivityTests` with the **Alertivity (Non-sandboxed)** scheme and normal code signing
(the tests explicitly inject the App Store distribution where required). For just the real
StoreKit adapter, select `NativeProPurchaseTests`. All native cases use the local fixture and
`SKTestSession`; they do not require an App Store Connect product or charge real money.
Tests load the fixture from their own bundle, so Xcode Cloud can run the built tests without
access to the original source checkout.

`NativeProPurchaseTests` is temporarily skipped only when the test runner receives
`CI_XCODE_CLOUD=TRUE`. Xcode Cloud forwards its system environment variables to test runners;
both schemes use the same suite-level Swift Testing condition. Required Cloud checks continue
to run the other suites, including fake-client Pro coverage. Local native tests remain enabled
by default. Cloud purchases have hung inside `Product.purchase()` despite suppressed dialogs;
the Store UI/AuthKit cause remains unverified. [AL-82](https://nobbby.atlassian.net/browse/AL-82)
tracks diagnosis and removal of this exclusion after reliable Cloud runs. To verify the skip
locally, pass `TEST_RUNNER_CI_XCODE_CLOUD=TRUE` to a focused `xcodebuild test` invocation.

| Scenario | Local coverage |
| --- | --- |
| Purchase, transaction completion, relaunch, restore | Native StoreKit and app-level tests |
| Ask to Buy approval and decline | Native StoreKit; approval exercises transaction updates |
| Interrupted purchase and subsequent resolution | Native StoreKit and transaction updates |
| Purchase failure and retry | Native injected purchase error |
| Product lookup failure and retry | Native injected offline error |
| Restore with no purchase; failed restore and recovery | Native StoreKit and injected offline error |
| Invalid transaction signature and later successful verification | Native verification-error injection |
| Refund, Free defaults, saved customization, and repurchase | Native refund plus activation refresh and settings integration |
| Cancellation without an error message | App-level tests for cancelled results and direct/wrapped cancellation errors |
| Native cancellation injection and retry | Native StoreKit safety check; see limitation below |
| Verified updates against stale cached queries | App-level regression test |
| Older lookup completing after a successful purchase | App-level concurrency regression test |
| Repeated purchase/restore actions while a purchase is pending | App-level concurrency regression test |
| Open-source build makes no Pro purchase-service calls | App-level regression test |

On the macOS 27 local test service, injecting `StoreKitError.userCancelled` through
`SKTestSession` produces `ASDServerErrorDomain` 907 and then `StoreKitError.unknown`, rather
than a normal cancelled result. The native test verifies that this grants no access and a retry
can succeed. Separate app-level tests verify that actual cancellation results and cancellation
errors show no failure message. Unknown errors remain visible.

The local service also did not deliver a refund update in the test host. Native refund tests
therefore exercise the explicit entitlement refresh used when the app becomes active. Actual
approval and interruption updates are tested natively; refund-update handling is additionally
covered with a verified delivery whose cached lookup still incorrectly grants access.

The two feature-boundary UI tests keep screenshot capture optional so their functional assertions
can run on hosts where macOS cannot create images. Set `ALERTIVITY_CAPTURE_UI_SCREENSHOTS=1`
in the UI test runner's environment to attach screenshots when a display is available.
