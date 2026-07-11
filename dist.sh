#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Cliq"
APP_DIR="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"

if [ ! -d "$APP_DIR" ]; then
    echo "Build the app first: ./build.sh"
    exit 1
fi

echo "==> Building disk image..."
rm -f "$DMG_NAME"
STAGING=$(mktemp -d)/dmg
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_NAME"
rm -rf "$(dirname "$STAGING")"

echo "==> Done: $DMG_NAME"
