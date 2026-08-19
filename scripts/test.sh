#!/usr/bin/env bash
# XCTest가 없는 CLT-only 환경용 테스트 러너.
# 테스트 실행 타깃을 빌드·실행하고, 실패 시 non-zero로 종료한다.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --target HighlightCursorTests
swift run HighlightCursorTests
