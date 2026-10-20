# Notifications and permissions

## Enable alerts

Use [Settings → Notifications](https://github.com/nobbbbby/Alertivity/wiki/Settings#notifications) to enable Alertivity’s toggle and macOS delivery. If macOS has not asked for permission yet, choose **Set Up Notifications…** in the app, then respond to the macOS authorization prompt. Monitoring continues if you decline.

After a denial, change authorization in macOS System Settings. Alertivity refreshes it when the app becomes active again. Focus and macOS delivery options can affect what you see or hear after a notification is submitted.

## When alerts are sent

A system metric must remain Critical for the selected High activity duration. The timer restarts when the selected trigger changes or no metric is Critical. Selection follows the [metric priority](https://github.com/nobbbbby/Alertivity/wiki/Metrics-and-Status).

In the source build, sustained [process activity](https://github.com/nobbbbby/Alertivity/wiki/Process-Insights#find-sustained-activity) can also trigger an alert. After a notification attempt, Alertivity waits for the selected **Cooldown** before attempting another. The default is ten minutes. System and process alerts share this interval. Changing it applies immediately against the last attempt; it does not start a new timer. The setting is saved, but the timer resets when the app restarts. Alerts are checked on each sample, so delivery can be later than the selected duration.

Custom duration and cooldown require Pro in the Mac App Store build; Free uses 60 seconds and 10 minutes. The open-source build has no purchase requirement.

Set **High activity duration** for how long activity must persist, and **Cooldown** for the gap between alerts, in [Settings](https://github.com/nobbbbby/Alertivity/wiki/Settings#notifications).

## Permissions by task

| Task | Permission or approval |
| --- | --- |
| Display local system readings | Notification authorization is not required. |
| Deliver alerts | macOS notification authorization, in addition to the app toggle. |
| Start at login | macOS may require Login Items approval; see [General settings](https://github.com/nobbbbby/Alertivity/wiki/Settings#general). |
| Reveal a process in Activity Monitor | System Events may require Automation or Accessibility approval; see [Activity Monitor troubleshooting](https://github.com/nobbbbby/Alertivity/wiki/Troubleshooting#activity-monitor-opens-without-finding-the-process). |

Process notifications can include an executable’s name and resource usage. Review macOS notification preview settings if that information should not appear on the lock screen.
