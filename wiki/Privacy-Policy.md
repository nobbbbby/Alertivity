# Privacy Policy

**Last updated: October 18, 2026**

This policy covers the Alertivity source reviewed on October 18, 2026. The App Store build provides system monitoring; the non-sandboxed source build also supports process monitoring. Features in an installed release may differ from the current source described in this wiki.

## Monitoring data stays on your Mac

Alertivity reads system activity to display status and identify sustained resource use. It does not upload monitored readings or executable paths to the developer. The app has no developer-operated analytics, advertising, tracking, or automatic crash-reporting service. No Alertivity account is required.

| Information processed | Purpose and storage |
| --- | --- |
| CPU utilization, physical memory usage, disk throughput, network byte totals, and running-application count | Display activity and calculate status. Current and recent samples stay in memory; the app does not save a metrics history. |
| Process identifiers, executable paths/names, and CPU/memory usage, when process sampling is available | Identify sustained activity and support local process actions. These details can also appear in local notifications. |
| Indicator choices, thresholds, notification preferences, onboarding outcome, and ignored executable paths | Remember your configuration in local macOS app preferences. |
| First monitoring date, up to three qualifying monitoring days, review-request dates, and attempted app versions | Limit requests for an App Store review. These values are stored in local app preferences. |

Network monitoring reads traffic counters; it does not inspect packet contents, browsing history, or message contents. Choosing an application or executable for the whitelist stores its executable path; that action does not upload the selected file.

## Notifications and permissions

Alertivity submits notifications locally through macOS. Notification content can include the triggering metric and value; process alerts can also include a process name, identifier, executable path, and resource usage in their content or action metadata. macOS manages notification presentation and retention. Use **Apple menu → System Settings → Notifications → Alertivity** to control delivery and previews, including what is visible on the lock screen.

Notification authorization is optional and does not enable or disable monitoring. Login-item registration and process actions may involve additional macOS approvals. See [Notifications and permissions](https://github.com/nobbbbby/Alertivity/wiki/Notifications-and-Permissions) for their purposes and configuration paths.

## Local diagnostic logs

Alertivity writes operational events and errors to the macOS unified log, including permission results, configuration changes, sampling failures, review-request decisions, and Pro purchase/access outcomes. Purchase logs exclude receipts, transaction identifiers, and payment information. Some error descriptions can contain diagnostic details or executable information. Logging does not automatically send these records to the developer. macOS controls unified-log storage and retention.

If you choose to share logs, screenshots, or a support report, review them first and remove private paths and unrelated personal information.

## Apple services and GitHub

The App Store review feature uses Apple’s StoreKit services to verify an eligible production installation and request a rating. The manual review action opens the App Store. Alertivity records an attempt locally; it does not receive or store your submitted rating or review text through that feature. Typing, clicking, or scrolling within the app delays a review prompt. This feature does not record the text you type or what you click.

The App Store build also uses StoreKit to load the Pro product and price, process purchases and restoration, and verify access and refunds. Apple handles the transaction and payment information; Alertivity does not operate a payment backend or require an Alertivity account. Purchase status is derived from StoreKit-verified transactions rather than a saved entitlement flag. Saved custom settings remain on your Mac when access changes. The open-source, non-sandboxed build does not contact the Pro purchase service.

Apple handles App Store interactions under its [App Store privacy notice](https://www.apple.com/legal/privacy/data/en/app-store/). Any diagnostics you elect to share through macOS or Apple are separate from Alertivity’s local logging.

This wiki and the public issue tracker are hosted by GitHub. Information you choose to post there is handled by GitHub and can be publicly visible. See the [GitHub Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

## Your controls and retention

Quit Alertivity to stop its monitoring. Use [Settings](https://github.com/nobbbbby/Alertivity/wiki/Settings) to change preferences or remove whitelist entries, and macOS System Settings to revoke relevant permissions or login approval.

Saved preferences and review-request history persist between launches; the app does not apply an automatic expiry to them. Removing the app does not guarantee that macOS preferences, logs, notifications, or backups are deleted. Alertivity has no developer-hosted monitoring account or metrics history to delete. Reports you send or post on GitHub are separate from the app’s local data.

## Questions and updates

For privacy questions, contact the maintainer through the [Alertivity issue tracker](https://github.com/nobbbbby/Alertivity/issues). Keep public requests general and do not attach sensitive information. This policy will be updated when the documented data practices change; the revision date appears above.
