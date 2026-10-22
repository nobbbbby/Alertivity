#!/bin/sh

# Keep diagnostics in the script log: Cloud does not retain arbitrary script-created files.
# Only collect for test execution, and never change the action's success/failure status.
case "${CI_XCODEBUILD_ACTION:-}" in
    test-without-building|test) ;;
    *) exit 0 ;;
esac

echo 'StoreKit diagnostics: test-runner environment'
/usr/bin/sw_vers
/usr/bin/xcodebuild -version
echo "StoreKit diagnostics: uid=$(/usr/bin/id -u) consoleUid=$(/usr/bin/stat -f %u /dev/console)"
/bin/launchctl managername 2>&1
/bin/launchctl manageruid 2>&1

echo 'StoreKit diagnostics: GUI-domain service registrations (names and status only)'
/bin/launchctl print "gui/$(/usr/bin/id -u)" 2>/dev/null |
    /usr/bin/awk '/^[[:space:]]*[0-9-]+[[:space:]]+[0-9-]+[[:space:]]+/ && /[Ss]tore[Kk]it|appstore/ { print }'

# Unified logging keeps private fields redacted; do not enable private-data collection.
# Restrict messages to the test app or local StoreKit testing environment, not account traffic.
echo 'StoreKit diagnostics: filtered test-service messages from the last 8 minutes'
/usr/bin/log show --last 8m --style compact --info --debug \
    --predicate '(process == "storekitagent" OR process == "storekitd" OR process == "appstoreagent" OR process == "appstored") AND (eventMessage CONTAINS[c] "com.Nobby.Alertivity" OR eventMessage CONTAINS[c] "StoreKitTest" OR eventMessage CONTAINS[c] "Octane")' \
    2>&1 || echo 'StoreKit diagnostics: unified logs were unavailable'

exit 0
