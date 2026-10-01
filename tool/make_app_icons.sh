#!/usr/bin/env bash
# Regenerates an app's icon set from the renderer in make_icon.py.
#
# Checked in as a script rather than as a one-off, because the icons are
# derived artefacts: when the mark changes, every size has to change with it,
# and doing that by hand is how an app ships with one stale size.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="${1:-ledger}"
ROOT="apps/$APP"

if [[ ! -d "$ROOT" ]]; then
  echo "No such app: $APP" >&2
  exit 2
fi

MASTER="$(mktemp -t icon-master-XXXXXX.png)"
trap 'rm -f "$MASTER"' EXIT
python3 tool/make_icon.py "$MASTER" >/dev/null

# `-alpha off` matters for the 1024 marketing icon: App Store Connect rejects
# an icon with an alpha channel, and the rejection arrives after upload.
emit() { convert "$MASTER" -resize "${1}x${1}" -alpha off -strip "$2"; }

IOS="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
emit 20   "$IOS/Icon-App-20x20@1x.png"
emit 40   "$IOS/Icon-App-20x20@2x.png"
emit 60   "$IOS/Icon-App-20x20@3x.png"
emit 29   "$IOS/Icon-App-29x29@1x.png"
emit 58   "$IOS/Icon-App-29x29@2x.png"
emit 87   "$IOS/Icon-App-29x29@3x.png"
emit 40   "$IOS/Icon-App-40x40@1x.png"
emit 80   "$IOS/Icon-App-40x40@2x.png"
emit 120  "$IOS/Icon-App-40x40@3x.png"
emit 120  "$IOS/Icon-App-60x60@2x.png"
emit 180  "$IOS/Icon-App-60x60@3x.png"
emit 76   "$IOS/Icon-App-76x76@1x.png"
emit 152  "$IOS/Icon-App-76x76@2x.png"
emit 167  "$IOS/Icon-App-83.5x83.5@2x.png"
emit 1024 "$IOS/Icon-App-1024x1024@1x.png"

RES="$ROOT/android/app/src/main/res"
emit 48  "$RES/mipmap-mdpi/ic_launcher.png"
emit 72  "$RES/mipmap-hdpi/ic_launcher.png"
emit 96  "$RES/mipmap-xhdpi/ic_launcher.png"
emit 144 "$RES/mipmap-xxhdpi/ic_launcher.png"
emit 192 "$RES/mipmap-xxxhdpi/ic_launcher.png"

# The store listing wants the 1024 on its own, outside the bundle.
mkdir -p "$ROOT/store"
emit 1024 "$ROOT/store/icon-1024.png"

echo "icons regenerated for $APP"
