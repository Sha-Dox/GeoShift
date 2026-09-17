#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
"$ROOT/make_app.sh"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$ROOT/dist/GeoShift.app" "$STAGE/GeoShift.app"
ln -s /Applications "$STAGE/Applications"

OUTPUT="$ROOT/dist/GeoShift-1.1-macOS.dmg"
rm -f "$OUTPUT"
hdiutil create -volname "GeoShift" -srcfolder "$STAGE" -ov -format UDZO "$OUTPUT"
echo "$OUTPUT"
