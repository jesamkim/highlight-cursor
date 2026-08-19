#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="HighlightCursor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/HighlightCursor" "$APP/Contents/MacOS/"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# 앱 아이콘(.icns)을 번들 Resources에 넣는다(서명 전에 넣어야 서명에 포함된다).
mkdir -p "$APP/Contents/Resources"
cp "assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# ad-hoc 코드 서명(Xcode 불필요, CLT의 codesign 사용).
# 서명이 없으면 재빌드마다 macOS가 "다른 앱"으로 보고 접근성 권한을 재요구한다.
# --force로 기존 서명을 덮어쓰고, 안정적 식별자로 서명해 권한이 유지되게 한다.
codesign --force --deep --sign - \
  --identifier "com.jesamkim.highlightcursor" \
  "$APP"
echo "Signed $APP (ad-hoc)"
echo "Built $APP"
