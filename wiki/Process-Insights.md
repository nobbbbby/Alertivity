# Process insights

Process monitoring requires the non-sandboxed source build. See [Getting started](https://github.com/nobbbbby/Alertivity/wiki/Getting-Started#choose-a-build).

## Find sustained activity

The menu bar lists processes with sustained high CPU or memory use. Set the limits and duration in [Settings](https://github.com/nobbbbby/Alertivity/wiki/Settings#process-detection-and-whitelist). Brief spikes do not appear. Changing the limits, duration, or ignore rules restarts the detection timer.

The list shows up to twelve processes. It does not measure per-process network or disk activity, and the current menu hides the process section when disk is the selected system trigger. If the section is empty, check [Troubleshooting](https://github.com/nobbbbby/Alertivity/wiki/Troubleshooting#detection-or-processes-are-missing).

## Actions

| Action | What it does |
| --- | --- |
| Show in Activity Monitor | Opens Activity Monitor and attempts to search for the process. macOS can require approval for System Events. |
| Add to Whitelist | Ignores processes with the same executable path. Its resource usage still counts in system readings. Use the [whitelist settings](https://github.com/nobbbbby/Alertivity/wiki/Settings#process-detection-and-whitelist) to remove a rule. |
| Force Quit Process | Tries to stop the process. Unsaved work may be lost. |

Force Quit sends `SIGTERM` first, then attempts `SIGKILL` only if that call fails. It does not wait and escalate based on whether the process exits. macOS can refuse termination, and the displayed process may have exited since sampling. If an action has no effect, inspect the current process in Activity Monitor.
