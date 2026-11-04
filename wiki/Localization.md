# Localization

Alertivity’s native catalogs cover the 50 locales listed by Apple for App Store metadata as of November 4, 2026. The original English, German, French, Japanese, and Simplified Chinese translations are preserved; additions are drafts marked `needs_review` until language and visual review is complete. Regional English variants preserve the source meaning with local spelling. The interface follows the language selected by macOS for the app. The wiki is maintained in English; its menu paths use the English interface labels.

## Locale coverage

The source of truth is `Configuration/SupportedLocalizations.json`, which maps [Apple’s App Store locale codes](https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes) to native bundle identifiers. App Store metadata and app bundles use different identifiers for some languages: for example, `ar-SA` → `ar`, `bn-BD` → `bn`, `no` → `nb`, and `en-US` → the development language `en`. These mappings keep app language selection language-wide where appropriate. Regional English, Canadian French, Mexican Spanish, and the two Portuguese variants have their own entries.

Arabic, Bangla (Bengali), Catalan, Simplified Chinese, Traditional Chinese, Croatian, Czech, Danish, Dutch, English (Australia, Canada, U.K., U.S.), Finnish, French (France, Canada), German, Greek, Gujarati, Hebrew, Hindi, Hungarian, Indonesian, Italian, Japanese, Kannada, Korean, Malay, Malayalam, Marathi, Norwegian Bokmål, Odia, Polish, Portuguese (Brazil, Portugal), Punjabi, Romanian, Russian, Slovak, Slovenian, Spanish (Mexico, Spain), Swedish, Tamil, Telugu, Thai, Turkish, Ukrainian, Urdu, and Vietnamese.

The manifest records App Store coverage, not an expansion to every macOS language or every storefront country. Both app targets use the same translations. Native macOS language selection and English fallback remain unchanged.

## Catalogs and ownership

| File | Content |
| --- | --- |
| `Alertivity/Resources/Localizable.xcstrings` | Interface text, onboarding, Pro purchase states, settings help, notification content, and accessibility labels |
| `Alertivity/Resources/InfoPlist.xcstrings` | Localized app name, copyright, and notification usage description |

Both targets share the catalogs. Keep the user-facing name **Alertivity** in every language; do not substitute the source target’s executable name. Feature availability depends on the build and verified Pro access, not the selected language. StoreKit supplies the localized purchase price. App Store listing and in-app purchase metadata are configured separately in App Store Connect.

`L10n.string` resolves keys and `L10n.format` formats localized messages. Many keys are passed dynamically, including Pro states and metric names, so extraction alone cannot prove completeness. An English sentence used as a key can use that key as its source-language fallback; a symbolic key such as `pro.pending` needs an explicit English value.

## Editing translations

1. Add or update the source wording and all supported translations together. Include tooltips, VoiceOver labels, validation errors, and notification actions, not only visible headings.
2. Preserve format argument types and counts. `%@` accepts a string and `%d` an integer. Use positional forms such as `%2$@` or `%3$d` when a language changes argument order; keep every argument’s original type.
3. Preserve behavior and numeric bounds: system CPU and memory allow 1–100%, throughput allows 0.1–100,000 MB/s, and Elevated must be below Critical. Process limits are separate. Keep notification duration and cooldown distinct.
4. Format lists through `L10n.list`, and retain locale-aware numeric and price formatting. Menu threshold summaries describe configured thresholds reached, including equality, rather than live readings or resource limits.
5. Review translations in context before marking them translated. Do not remove dynamically referenced keys just because Xcode cannot discover their use. Keep translator comments on ambiguous text and format arguments.

The notification footer combines a duration (`%d`) with a localized cooldown (`%@`). Its source-build variant also mentions process alerts. Free App Store controls and the footer show effective defaults; a translation must not imply that preserved custom settings are currently active.

## Validation

Run `python3 scripts/validate-localizations.py` to check both catalogs for valid JSON, coverage of the manifest’s locales, matching format arguments (including positional reordering), accidentally escaped XML entities, and project language registration. The command logs translation-state counts; `needs_review` entries compile and remain explicitly pending review. Xcode Cloud runs this check after checkout. Use `python3 scripts/validate-localizations.py --require-reviewed` as a release check: it fails while any translation is still marked `needs_review`. Run `python3 scripts/test-validate-localizations.py` when changing the validator. Scan Swift references, including dynamically selected keys, against the catalog. Empty layout strings and separators are intentional; brand names and format-only strings may be identical across languages.

Build both **Alertivity** and **Alertivity (Non-sandboxed)** to compile the shared catalogs. Review Settings, onboarding, purchase messages, threshold errors, notifications, and accessibility descriptions in each language when changing their layout or meaning. A successful build verifies catalog compilation, not visual fit or native-speaker review.

See [Developer guide](https://github.com/nobbbbby/Alertivity/wiki/Developer-Guide) for builds and [Editing the wiki](https://github.com/nobbbbby/Alertivity/wiki/Maintaining-the-Wiki) for publication.

## Review and release tracking (AL-85)

The rollout scope is all 50 App Store locales in one app update. Draft coverage and compiler checks do not establish native fluency or visual fit. `LocalizationTests` checks every compiled language bundle against English keys, localized app names, exact language selection, and the English fallback. Review onboarding, each Settings tab, purchase and restore messages, menu summaries, notifications, and VoiceOver in both app variants before release. Check Arabic, Hebrew, and Urdu right-to-left layouts and mixed-direction metric values; also check Indic scripts and long European labels for clipping.

Screenshot refresh and App Store Connect screenshot coverage are tracked in [AL-87](https://nobbby.atlassian.net/browse/AL-87). App Store listing copy and Pro product metadata also require separate localization and review. In-app price formatting remains StoreKit’s responsibility.

### Layout and UI checks

Settings starts at 400 points. `SettingsTabWidth` expands it only when native tabs overflow, within the available screen width; older tab-strip presentations use their native minimum size. Each pane receives the same adaptive width, including its padding, so text and controls reflow inside the tab view. Pro actions stack when their full labels and price do not fit side by side. The disclosure chevron follows reading direction and threshold headers wrap inside their existing columns.

For the opt-in screenshot matrix, build Debug app bundles. Set `TEST_RUNNER_ALERTIVITY_LOCALIZATION_APPS` to absolute bundle paths separated by `|`, and optionally set `TEST_RUNNER_ALERTIVITY_LOCALIZATION_LOCALES` to comma-separated bundle identifiers. Run `AlertivityUITests/LocalizationReviewTests/testLocalizedOnboardingAndSettings` with `xcodebuild test`. Without a locale filter it captures every bundled locale. Test launches isolate preferences, skip login registration, apply native RTL test flags, and place test windows on the primary display. They do not click permission or purchase buttons.

Enable `TEST_RUNNER_ALERTIVITY_REQUIRE_VISIBLE_TABS=1` to require tabs without overflow and preserve the English 400-point baseline. Enable `TEST_RUNNER_ALERTIVITY_REQUIRE_CONTENT_FIT=1` to check visible text and controls against the window’s horizontal bounds. Screenshots are attached to the `.xcresult` for language and layout review.

### Review status

New locale values remain `needs_review`. Automated coverage, format checks, compiled-bundle tests, and UI navigation checks do not establish native fluency. Native-speaker review and complete visual review remain pending before release; `--require-reviewed` enforces the catalog review state.
