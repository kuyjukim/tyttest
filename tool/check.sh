#!/usr/bin/env bash
# Runs everything CI runs, in the same order, so a green local run means a
# green CI run.
#
# Usage:
#   tool/check.sh              analyze and test every package
#   tool/check.sh paper grove  only those packages
set -euo pipefail

cd "$(dirname "$0")/.."

ALL_PACKAGES=(packages/paper apps/grove apps/inkwell apps/ledger apps/stroke)

# Calendar arithmetic is the part of this suite most likely to be wrong in a
# way that only shows up somewhere else in the world, so the date-sensitive
# suites run in three zones: one with no DST, one with DST, and one on a
# half-hour offset.
TIMEZONES=(UTC America/New_York Asia/Kolkata)

if [[ $# -gt 0 ]]; then
  PACKAGES=()
  for name in "$@"; do
    for candidate in "${ALL_PACKAGES[@]}"; do
      if [[ "$(basename "$candidate")" == "$name" ]]; then
        PACKAGES+=("$candidate")
      fi
    done
  done
  if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    echo "No package matched: $*" >&2
    echo "Known packages: ${ALL_PACKAGES[*]##*/}" >&2
    exit 2
  fi
else
  PACKAGES=("${ALL_PACKAGES[@]}")
fi

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

for package in "${PACKAGES[@]}"; do
  step "$package: dependencies"
  (cd "$package" && flutter pub get)

  step "$package: analyze"
  # `flutter analyze` exits non-zero for infos as well as errors, which is
  # what the workspace's strict lint set is for.
  (cd "$package" && flutter analyze)

  step "$package: test"
  (cd "$package" && flutter test)
done

# Only the packages that actually do calendar work need the extra zones;
# running everything three times would triple CI for no information.
for package in packages/paper apps/grove apps/ledger; do
  for zone in "${TIMEZONES[@]:1}"; do
    step "$package: test (TZ=$zone)"
    (cd "$package" && TZ="$zone" flutter test)
  done
done

# The Android build is the one build this repository cannot run - the SDK
# platform is served only by dl.google.com - so the cheap half of what the
# build would have told us is checked here instead. Only when the whole
# repository is being checked: it is about resources, not about one package.
if [[ $# -eq 0 ]]; then
  step "android resources"
  tool/check_android_res.py

  step "store listing fields"
  tool/check_listing.py apps/ledger/store
fi

step "all checks passed"
