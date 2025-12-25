## 1. Investigation
- [ ] 1.1 Reproduce `Launch at login` toggle behavior and observe `SMAppService.mainApp.status` changes in-session
- [ ] 1.2 Reproduce `Hide app icon in Dock` on macOS 15.7 to understand activation policy handling with/without visible windows

## 2. Implementation
- [x] 2.1 Apply launch-at-login changes so registration/unregistration occurs immediately and preferences stay in sync on failure
- [x] 2.2 Update Dock visibility logic to reliably hide/show on macOS 15.7 while keeping window-visibility rules intact
- [x] 2.3 Add defensive handling/fallbacks so settings UI reflects actual state if system calls fail

## 3. Validation
- [ ] 3.1 Manually toggle launch-at-login on/off without relaunch and confirm SMAppService status matches
- [ ] 3.2 Manually toggle Dock visibility on macOS 15.7 with/without visible windows and verify activation policy matches expectations
- [ ] 3.3 Confirm menu bar insertion/notification behavior remains unchanged and preferences persist across relaunch
