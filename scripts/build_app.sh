#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# --- 직접 swiftc 빌드 ---
# macOS 26 + Swift 6.3에서 SwiftPM의 PackageDescription dylib 심볼 불일치 문제를 우회하기 위해
# swiftc로 직접 컴파일한다. SwiftPM 문제가 Apple 업데이트로 해결되면 swift build로 복귀 가능.

BUILD_DIR=".build/direct"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
TARGET="arm64-apple-macosx14.0"

mkdir -p "$BUILD_DIR"

echo "Compiling HighlightCursorCore..."
CORE_SOURCES=$(find Sources/HighlightCursorCore -name "*.swift")
swiftc -parse-as-library -emit-module -module-name HighlightCursorCore \
  -emit-module-path "$BUILD_DIR/HighlightCursorCore.swiftmodule" \
  -emit-library -o "$BUILD_DIR/libHighlightCursorCore.dylib" \
  $CORE_SOURCES \
  -sdk "$SDK" -target "$TARGET"

echo "Compiling HighlightCursor..."
APP_SOURCES=$(find Sources/HighlightCursor -name "*.swift")
swiftc -module-name HighlightCursor \
  -I "$BUILD_DIR" -L "$BUILD_DIR" -lHighlightCursorCore \
  $APP_SOURCES \
  -sdk "$SDK" -target "$TARGET" \
  -o "$BUILD_DIR/HighlightCursor"

# --- .app 번들 조립 ---
APP="HighlightCursor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BUILD_DIR/HighlightCursor" "$APP/Contents/MacOS/"
cp "$BUILD_DIR/libHighlightCursorCore.dylib" "$APP/Contents/MacOS/"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# 앱 아이콘(.icns)을 번들 Resources에 넣는다(서명 전에 넣어야 서명에 포함된다).
mkdir -p "$APP/Contents/Resources"
cp "assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# dylib rpath 설정
install_name_tool -add_rpath @executable_path "$APP/Contents/MacOS/HighlightCursor" 2>/dev/null || true
install_name_tool -change "$BUILD_DIR/libHighlightCursorCore.dylib" "@rpath/libHighlightCursorCore.dylib" "$APP/Contents/MacOS/HighlightCursor"
install_name_tool -id "@rpath/libHighlightCursorCore.dylib" "$APP/Contents/MacOS/libHighlightCursorCore.dylib"

# ad-hoc 코드 서명(Xcode 불필요, CLT의 codesign 사용).
# 서명이 없으면 재빌드마다 macOS가 "다른 앱"으로 보고 접근성 권한을 재요구한다.
# --force로 기존 서명을 덮어쓰고, 안정적 식별자로 서명해 권한이 유지되게 한다.
codesign --force --deep --sign - \
  --identifier "com.jesamkim.highlightcursor" \
  "$APP"
echo "Signed $APP (ad-hoc)"
echo "Built $APP"
