#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"

swift build -c release

APP="$ROOT/dist/GeoShift.app"
CONTENTS="$APP/Contents"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/.build/release/GeoShift" "$CONTENTS/MacOS/GeoShift"
cp "$ROOT/Resources/AppIcon-Simple.icns" "$CONTENTS/Resources/AppIcon-Simple.icns"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
echo "$APP"
