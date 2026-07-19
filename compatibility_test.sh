#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build/compatibility"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"
SOURCE_FILES=("$ROOT_DIR/Sources/"*.swift)
TARGET_VERSIONS=("10.15" "11.0" "12.0" "13.0" "14.0" "15.0" "26.0" "$MIN_MACOS")
ARCHS_TO_TEST=("arm64" "x86_64")

mkdir -p "$BUILD_DIR"
touch "$ROOT_DIR/build/.metadata_never_index" "$BUILD_DIR/.metadata_never_index"

"$ROOT_DIR/test.sh"

typeset -A SEEN_VERSIONS
UNIQUE_TARGET_VERSIONS=()
for version in "${TARGET_VERSIONS[@]}"; do
  if [[ -z "${SEEN_VERSIONS[$version]:-}" ]]; then
    UNIQUE_TARGET_VERSIONS+=("$version")
    SEEN_VERSIONS[$version]=1
  fi
done

for mode in direct appstore; do
  for version in "${UNIQUE_TARGET_VERSIONS[@]}"; do
    for arch in "${ARCHS_TO_TEST[@]}"; do
      output="$BUILD_DIR/MouseRun-$mode-$arch-macos$version"
      args=(
        -target "$arch-apple-macosx$version"
        -framework Cocoa
        -framework IOBluetooth
        -framework IOKit
      )

      if [[ "$mode" == "appstore" ]]; then
        args+=(
          -D APP_STORE
          -framework ServiceManagement
        )
      fi

      swiftc "${args[@]}" "${SOURCE_FILES[@]}" -o "$output"
      echo "Compiled $mode for macOS $version $arch"
    done
  done
done

echo "MouseRun compatibility matrix passed"
