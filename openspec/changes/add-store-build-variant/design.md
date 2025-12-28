## Context
Alertivity currently shells out to `/bin/ps` to identify high-activity processes. App Sandbox forbids this in TestFlight/App Store builds, which disables per-process flagging and downstream notifications without user-visible explanation.

## Goals / Non-Goals
- Goals: Preserve full per-process alerting in a direct (non-sandboxed) build; provide a clear, stable sandboxed behavior that avoids silent failures; keep system-level status/notifications intact.
- Non-Goals: Bypass App Sandbox restrictions or use private entitlements/API.

## Decisions
- Decision: Introduce two distribution builds: App Store (sandboxed) and Direct (non-sandboxed), each with explicit entitlements.
- Decision: Add a runtime capability check for process sampling (sandbox present or `ps` unavailable) and cache the result for UI/notification gating.
- Decision: Surface a short Settings note explaining that per-process alerts require the Direct build when sandboxed.

## Risks / Trade-offs
- Risk: Feature disparity between App Store and Direct builds may confuse users.
  - Mitigation: Provide a clear, concise Settings note and avoid showing empty process UI in sandboxed builds.
- Risk: Runtime capability detection could be noisy if it retries `ps` frequently.
  - Mitigation: Cache the capability state and update only on explicit retries/refresh.

## Migration Plan
- Add build configuration(s) and entitlements for sandboxed vs non-sandboxed builds.
- Implement capability detection and surface it in settings + notification gating.
- Verify App Store build no longer attempts process sampling and Direct build retains per-process alerts.

## Open Questions
- Should the app expose the build type in About or diagnostics for support?
- Should the Detection settings be partially disabled when process sampling is unavailable?
