#!/bin/bash
# Rakit SecondDock.app dari SwiftPM (cukup CLT). Pakai: ./scripts/build-app.sh
set -e
cd "$(dirname "$0")/.."

swift build -c release --product SecondDock

APP="SecondDock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/SecondDock" "$APP/Contents/MacOS/SecondDock"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" 2>/dev/null || true

echo "OK -> $APP"
