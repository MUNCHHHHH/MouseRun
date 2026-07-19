#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_BINARY="$BUILD_DIR/MouseDetectionTests"

mkdir -p "$BUILD_DIR"
touch "$ROOT_DIR/build/.metadata_never_index" "$BUILD_DIR/.metadata_never_index"

swiftc \
  -framework IOBluetooth \
  -framework IOKit \
  "$ROOT_DIR/Sources/MouseDetection.swift" \
  "$ROOT_DIR/Tests/MouseDetectionTests.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY"
