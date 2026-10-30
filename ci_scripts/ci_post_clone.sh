#!/bin/sh
# Validate project inputs after checkout; store metadata stays local.
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_directory=${CI_PRIMARY_REPOSITORY_PATH:-$(dirname -- "$script_directory")}
cd "$repository_directory"

printf '%s\n' '{"level":"info","event":"project_inputs_validation_started"}'
plutil -lint Alertivity.xcodeproj/project.pbxproj Configuration/Info.plist
printf '%s\n' '{"level":"info","event":"project_inputs_validation_completed"}'
