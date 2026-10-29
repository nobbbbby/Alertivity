# Settings

Open **Alertivity’s menu bar indicator → Open Settings…**. Paths below use the app’s English labels. Hover over a tab for its description. Notification and detection notes that include configured values remain visible below the controls.

## General

| Setting | Path | Notes |
| --- | --- | --- |
| Dock visibility | Settings → General → Hide app icon in Dock | Hides the Dock icon while monitoring continues. |
| Automatic startup | Settings → General → Launch at login | Starts Alertivity when you log in. |

If macOS requires login-item approval, open **Apple menu → System Settings → General → Login Items** and approve Alertivity. macOS section names can vary by version.

Choose **Help → Send Feedback…** to open a new GitHub issue in your default browser to report a bug or suggest an improvement. A GitHub account is required to submit an issue.

## Menu bar

| Setting | Path | Notes |
| --- | --- | --- |
| Indicator visibility | Settings → Menu Bar → Show indicator | Turning this off hides the indicator even during Critical activity. |
| Default reading | Settings → Menu Bar → Default icon type | Choose Status, CPU, memory, disk, or network. |
| Automatic metric selection | Settings → Menu Bar → Auto switch to busiest metric | Follows a Critical metric, then returns to the default. |
| Auto-switch priority | Settings → Menu Bar → Metric priority | Expand Metric priority, then use the up/down arrows to order CPU, memory, disk, and network. The highest listed Critical metric wins. Reset Priority restores CPU → Memory → Disk → Network. |
| Show only during Critical activity | Settings → Menu Bar → Only show on high activity | Hides the indicator at Normal and Elevated status. |
| Metric symbols | Settings → Menu Bar → Show metric icon | Available when the default icon type is a metric. Shows a symbol beside the value. Auto switch keeps this on and disables editing; the explanation appears directly below the control. |

If the indicator is hidden, reopen Alertivity to access Settings. Auto-switch timing is described in [Metrics and status](https://github.com/nobbbbby/Alertivity/wiki/Metrics-and-Status).

## System thresholds

Open **Settings → Thresholds**, then edit the Elevated and Critical columns for the relevant row:

| Setting | Path | Allowed values |
| --- | --- | --- |
| System CPU severity | Settings → Thresholds → System CPU → Elevated / Critical | 1–100% |
| System memory severity | Settings → Thresholds → System memory → Elevated / Critical | 1–100% of physical memory |
| Disk activity severity | Settings → Thresholds → Disk throughput → Elevated / Critical | 0.1–100,000 MB/s, combined reads and writes |
| Network activity severity | Settings → Thresholds → Network throughput → Elevated / Critical | 0.1–100,000 MB/s, combined receives and sends |
| Restore system threshold defaults | Settings → Thresholds → Reset to Defaults | Resets all four metrics. |

These controls require Pro in the Mac App Store build and are always available in the open-source build. Elevated must be strictly below Critical. Valid edits apply immediately; invalid edits show an explanation and preserve the last valid configuration.

Default values are listed in [Metrics and status](https://github.com/nobbbbby/Alertivity/wiki/Metrics-and-Status).

## Notifications

| Setting | Path | Notes |
| --- | --- | --- |
| App notification toggle | Settings → Notifications → Enable system notifications | Requires macOS notification permission as well. |
| Time between alerts | Settings → Notifications → Cooldown | Choose 1, 5, 10, 15, 30, or 60 minutes; the default is 10. Shared by system and process alerts. |
| Sustained-activity duration | Settings → Notifications → High activity duration | Choose 30, 60, 120, 240, or 600 seconds; the default is 60 seconds. |
| macOS notification delivery | Apple menu → System Settings → Notifications → Alertivity | macOS controls delivery, sounds, and previews here. |

The footer shows the effective duration and minimum interval between alerts, including Free defaults when Pro is locked. Turning off notifications disables the Cooldown picker; high-activity duration remains available to Pro and source-build users because it also controls sustained process detection when available. See [Notifications and permissions](https://github.com/nobbbbby/Alertivity/wiki/Notifications-and-Permissions) for alert timing.

## Process detection and whitelist

These paths appear only when process sampling is available in the non-sandboxed build.

| Setting | Path | Notes |
| --- | --- | --- |
| Process CPU limit | Settings → Detection → CPU threshold | Enter 1–100%; the default is 80%. |
| Process memory limit | Settings → Detection → Memory threshold | Enter 5–50% of physical memory; the default is 25%. |
| Exclude an application or executable | Settings → Detection → Whitelist → Add | Choose an application or executable file, then confirm Add. |
| Resume detection for an ignored process | Settings → Detection → Whitelist → the process’s minus button | Remove its saved executable-path rule. The button’s accessibility label is Remove ignored process. |

See [Process insights](https://github.com/nobbbbby/Alertivity/wiki/Process-Insights) for how the list and actions work.

## Free and Pro in the Mac App Store build

Alertivity Pro unlocks customization of system CPU, memory, disk, and network thresholds,
notification cooldown, and high-activity duration. Other current monitoring, notification,
menu bar, and general features remain free.

Without Pro, monitoring uses the default thresholds listed in [Metrics and status](https://github.com/nobbbbby/Alertivity/wiki/Metrics-and-Status),
a 10-minute notification cooldown, and a 60-second high-activity duration. The corresponding
controls show these effective defaults and are disabled. Hover over the lock beside a restricted
setting for an explanation. Saved custom values are preserved,
including values from an earlier version, and become active again when Pro access is verified.
Refunding or revoking Pro returns monitoring to the defaults without deleting saved values.

Open **Settings → Pro** to purchase the one-time unlock or restore an existing purchase with your App Store account. Choose **Unlock Pro — [price]** to buy or **Restore Purchases** to restore. If purchase options have not loaded, choose **Load Purchase Options**. Actions are disabled while a request is running.

The note below the buttons shows purchase status or explains that this is a one-time purchase without a subscription. The price comes from the App Store. Pending purchases unlock customization after approval; cancelled or unverified purchases do not grant access.

The open-source, non-sandboxed build remains fully unlocked. It does not require a purchase
for customization or any process feature and does not contact the Pro purchase service.

## App Store reviews

Choose **Alertivity → Write Review…** to open the App Store review page at any time. If the App Store cannot open, Alertivity shows an error and you can try again later.

A verified production App Store installation may also request a review automatically in **Settings → General**, after at least seven days since first monitoring and activity on three distinct days. Requests wait for 30 seconds without interaction, live data, a non-Critical status, and an active Settings window without a sheet or modal dialog. Onboarding blocks the request. Debug, TestFlight, and source builds do not request reviews automatically.

The app records at most one automatic attempt per version and waits at least 120 days between attempts; opening the manual review page also delays future automatic requests. macOS decides whether to show a prompt, and Alertivity does not know whether you submitted a review.
