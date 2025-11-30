# Change: Add auto-switching metric icon mode

## Why
Users want the menu bar icon to surface whichever metric is currently most active without constant manual switching, while still honoring their preferred icon when the system is calm.

## What Changes
- Add an Auto switch mode that rotates the menu bar metric icon to the highest-activity metric with deterministic CPU > Memory > Network > Disk priority when multiple metrics are active.
- Fall back to the user-selected default icon type whenever activity is normal; the option is labeled Default icon type and appears second in the control list for clarity.
- Keep Show metric icon forced on while Auto switch is enabled, keep Only show on high activity available alongside Auto switch, and add a short helper note explaining how Auto switch behaves.

## Impact
- Affected specs: settings
- Affected code: menu bar icon rendering and selection logic, settings UI/state for menu icon mode and fallback type, menu preferences persistence
