# Localization

Alertivity supports English (`en`), German (`de`), French (`fr`), Japanese (`ja`), and Simplified Chinese (`zh-Hans`). The interface follows the language selected by macOS for the app. The wiki is maintained in English; its menu paths use the English interface labels.

## Catalogs and ownership

| File | Content |
| --- | --- |
| `Alertivity/Resources/Localizable.xcstrings` | Interface text, onboarding, Pro purchase states, settings help, notification content, and accessibility labels |
| `Alertivity/Resources/InfoPlist.xcstrings` | Localized app name, copyright, and notification usage description |

Both targets share the catalogs. Keep the user-facing name **Alertivity** in every language; do not substitute the source target’s executable name. Feature availability depends on the build and verified Pro access, not the selected language. StoreKit supplies the localized purchase price. App Store listing and in-app purchase metadata are configured separately in App Store Connect.

`L10n.string` resolves keys and `L10n.format` formats localized messages. Many keys are passed dynamically, including Pro states and metric names, so extraction alone cannot prove completeness. An English sentence used as a key can use that key as its source-language fallback; a symbolic key such as `pro.pending` needs an explicit English value.

## Editing translations

1. Add or update the source wording and all four translations together. Include tooltips, VoiceOver labels, validation errors, and notification actions, not only visible headings.
2. Preserve format argument types and counts. `%@` accepts a string and `%d` an integer. Use positional forms such as `%2$@` or `%3$d` when a language changes argument order; keep every argument’s original type.
3. Preserve behavior and numeric bounds: system CPU and memory allow 1–100%, throughput allows 0.1–100,000 MB/s, and Elevated must be below Critical. Process limits are separate. Keep notification duration and cooldown distinct.
4. Format lists through `L10n.list`, and retain locale-aware numeric and price formatting. Menu threshold summaries describe configured thresholds reached, including equality, rather than live readings or resource limits.
5. Review translations in context before marking them translated. Do not remove dynamically referenced keys just because Xcode cannot discover their use. Keep translator comments on ambiguous text and format arguments.

The notification footer combines a duration (`%d`) with a localized cooldown (`%@`). Its source-build variant also mentions process alerts. Free App Store controls and the footer show effective defaults; a translation must not imply that preserved custom settings are currently active.

## Validation

Check both catalogs for valid JSON, coverage of all supported locales, unresolved translation states, and matching format arguments. Scan Swift references, including dynamically selected keys, against the catalog. Empty layout strings and separators are intentional; brand names and format-only strings may be identical across languages.

Build both **Alertivity** and **Alertivity (Non-sandboxed)** to compile the shared catalogs. Review Settings, onboarding, purchase messages, threshold errors, notifications, and accessibility descriptions in each language when changing their layout or meaning. A successful build verifies catalog compilation, not visual fit or native-speaker review.

See [Developer guide](https://github.com/nobbbbby/Alertivity/wiki/Developer-Guide) for builds and [Editing the wiki](https://github.com/nobbbbby/Alertivity/wiki/Maintaining-the-Wiki) for publication.
