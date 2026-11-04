# Metrics and status

Alertivity samples every five seconds by default. Pro and source-build users can choose a 3-, 5-, or 10-second interval in **Settings → General**. Shorter intervals respond sooner but increase CPU/energy use; longer intervals reduce work and may miss short spikes. Changes replace the active timer without resetting rate baselines. Disk and network rates divide byte deltas by actual elapsed time, and CPU uses differences in processor ticks. CPU and throughput readings need successive samples to calculate activity, so initial readings can be zero or show that data is being collected.

The overall status follows the highest severity among CPU, memory, disk, and network. **Normal** means all readings are below their elevated thresholds; **Elevated** and **Critical** mean at least one reading reached that level. At equal severity, trigger priority is CPU, memory, disk, then network. Critical means a threshold was reached. It does not indicate a hardware fault.

## Default system thresholds

| Metric | Elevated at | Critical at | Measurement |
| --- | --- | --- | --- |
| CPU | 50% | 80% | Total system processor utilization |
| Memory | 70% | 85% | Used physical memory as a share of total |
| Disk | 30 MB/s | 120 MB/s | Combined read and write throughput |
| Network | 5 MB/s | 20 MB/s | Combined receive and send throughput |

Values below Elevated are Normal. At a threshold, the higher status applies: CPU at 80% is Critical with the defaults. MB/s uses decimal megabytes (1 MB = 1,000,000 bytes), not megabits. Customize these values under **Settings → Thresholds** with Pro in the App Store build, or without a purchase in the open-source build; process detection has separate controls.

## Menu summaries

A summary such as “Alert thresholds reached: CPU 80% and Memory 70%” shows the configured thresholds reached by current activity. The live readings are in the metric rows below. “Reached” includes equality; thresholds flag activity and do not cap resource use.

Each affected metric shows the Elevated or Critical threshold for its current severity, including custom values. Critical metrics appear first; CPU, memory, disk, then network break ties.

## Reading limitations

Memory usage is calculated from physical memory minus free and inactive pages. It is not the same measurement as Activity Monitor’s Memory Pressure graph. Network totals exclude loopback and several virtual/tunnel interface types to avoid double counting; they are not a per-app traffic meter or a connection speed test. Disk activity is throughput, not remaining storage space.

If a system reading is unavailable, Alertivity may keep its last value. It also retains the previous disk reading when a sample reports zero. If a reading seems stuck, compare it with Activity Monitor.

Auto switch chooses a metric at **Critical** (default), or **Elevated or higher** when customized, using the order saved in **Settings → Menu Bar → Metric priority** (CPU, memory, disk, then network by default), after two consecutive matching samples. When none meets the activation level, it returns to the chosen default after the same sampling check. Selection uses severity and your metric priority, not the raw values. Custom activation and ordering require Pro in the App Store build and are always available in open-source builds. Free uses Critical-only activation and CPU → Memory → Disk → Network. The custom order and activation level affect only Auto switch; notifications and indicator visibility retain their own rules.

Two-sample confirmation normally takes one to two sampling intervals from a change in activity (5–10 seconds by default, 3–6 seconds at a 3-second interval, or 10–20 seconds at 10 seconds). Transient or changing candidates restart confirmation. Status stabilization also uses two matching samples. Notification duration and cooldown use elapsed time, not sample counts, and are evaluated when samples arrive; after a duration expires, detection can wait up to another sampling interval. Slow collection, a busy main thread, or sleep can delay these checks further. Reconfiguring the interval does not restart notification dwell or cooldown.

See [Settings](https://github.com/nobbbbby/Alertivity/wiki/Settings) and [Notifications and permissions](https://github.com/nobbbbby/Alertivity/wiki/Notifications-and-Permissions).
