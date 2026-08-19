#!/usr/bin/env bash
# XCTest가 없는 CLT-only 환경용 테스트 러너.
# 테스트 실행 타깃을 빌드·실행하고, 실패 시 non-zero로 종료한다.
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR=".build/direct"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
TARGET="arm64-apple-macosx14.0"

mkdir -p "$BUILD_DIR"

# Core 라이브러리 빌드 (이미 있으면 덮어쓰기)
CORE_SOURCES=$(find Sources/HighlightCursorCore -name "*.swift")
swiftc -parse-as-library -emit-module -module-name HighlightCursorCore \
  -emit-module-path "$BUILD_DIR/HighlightCursorCore.swiftmodule" \
  -emit-library -o "$BUILD_DIR/libHighlightCursorCore.dylib" \
  $CORE_SOURCES \
  -sdk "$SDK" -target "$TARGET"

# 테스트 바이너리 빌드
TEST_SOURCES=$(find Tests/HighlightCursorTests -name "*.swift")
swiftc -module-name HighlightCursorTests \
  -I "$BUILD_DIR" -L "$BUILD_DIR" -lHighlightCursorCore \
  $TEST_SOURCES \
  -sdk "$SDK" -target "$TARGET" \
  -o "$BUILD_DIR/HighlightCursorTests"

# 실행
DYLD_LIBRARY_PATH="$BUILD_DIR" "$BUILD_DIR/HighlightCursorTests"
