#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Cliq"
SRC="./${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

if [ ! -d "$SRC" ]; then
    echo "Build the app first: ./build.sh"
    exit 1
fi

echo "==> Installing to /Applications..."
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

echo "==> Launching Cliq..."
open "$DEST"

echo "==> Installed. Click the Cliq icon in the menu bar and choose 'Start at Login' to keep it running after reboot."
