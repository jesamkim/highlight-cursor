#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="HighlightCursor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/HighlightCursor" "$APP/Contents/MacOS/"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
echo "Built $APP"
