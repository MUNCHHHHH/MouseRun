#!/bin/zsh
set -euo pipefail

MODE="direct"
CLEAN=false
if [[ $# -gt 0 ]]; then
  case "$1" in
    clean)
      CLEAN=true
      shift
      ;;
    direct|appstore)
      MODE="$1"
      shift
      ;;
  esac
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build"
DIST_ROOT="$ROOT_DIR/dist"

if [[ "$CLEAN" == true ]]; then
  rm -rf "$BUILD_ROOT" "$DIST_ROOT"
  echo "Cleaned MouseRun build and dist artifacts."
  exit 0
fi

BUILD_DIR="$ROOT_DIR/build/$MODE"
DIST_DIR="$ROOT_DIR/dist/$MODE"
APP_BUNDLE="$BUILD_DIR/MouseRun.app"
INSTALL_BUNDLE="/Applications/MouseRun.app"
ICON_SOURCE="$ROOT_DIR/Resources/AppIconTransparent.png"
ENTITLEMENTS="$ROOT_DIR/Resources/MouseRun-AppStore.entitlements"

if [[ ! -f "$ICON_SOURCE" ]]; then
  ICON_SOURCE="$PROJECT_ROOT/assets/MouseRun/originals/앱 아이콘 사진.png"
fi

APP_NAME="MouseRun"
PUBLISHER="MUNCH"
GITHUB_OWNER="MUNCHHHHH"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/Resources/Info.plist")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT_DIR/Resources/Info.plist")"
MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$ROOT_DIR/Resources/Info.plist")"
ARCH_LIST="${ARCHS:-arm64 x86_64}"
ARCH_ARRAY=(${=ARCH_LIST})
SOURCE_FILES=("$ROOT_DIR/Sources/"*.swift)
DO_INSTALL=false
PACKAGE=true

usage() {
  cat <<EOF
Usage:
  ./build.sh clean
  ./build.sh [direct] [--install] [--no-package]
  ./build.sh appstore

Modes:
  clean       Removes generated build and app-local dist artifacts.
  direct      Builds the full direct-distribution app. This is the default.
  appstore    Builds the sandbox-safe App Store variant.

Options for direct mode:
  --install      Also copy the built app to /Applications.
  --no-package   Build the app bundle only.

Environment:
  ARCHS="arm64"                         Build selected architectures.
  CODESIGN_IDENTITY="Name"              Sign direct builds with a certificate.
  APP_STORE_SIGN_IDENTITY="Name"        Sign App Store app bundle.
  APP_STORE_INSTALLER_IDENTITY="Name"   Create signed App Store .pkg.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      DO_INSTALL=true
      shift
      ;;
    --no-package)
      PACKAGE=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ "$MODE" == "appstore" ]]; then
  PACKAGE=false
fi

rm -rf "$BUILD_DIR"
if [[ "$PACKAGE" == true ]]; then
  rm -rf "$DIST_DIR"
fi
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
touch "$BUILD_ROOT/.metadata_never_index" "$BUILD_DIR/.metadata_never_index"

THIN_BINARIES=()
for arch in "${ARCH_ARRAY[@]}"; do
  THIN_BINARY="$BUILD_DIR/$APP_NAME-$arch"
  SWIFTC_ARGS=(
    -target "$arch-apple-macosx$MIN_MACOS"
    -framework Cocoa
    -framework IOBluetooth
    -framework IOKit
  )

  if [[ "$MODE" == "appstore" ]]; then
    SWIFTC_ARGS+=(
      -D APP_STORE
      -framework ServiceManagement
    )
  fi

  swiftc "${SWIFTC_ARGS[@]}" "${SOURCE_FILES[@]}" -o "$THIN_BINARY"
  THIN_BINARIES+=("$THIN_BINARY")
done

if [[ ${#THIN_BINARIES[@]} -eq 1 ]]; then
  cp "${THIN_BINARIES[1]}" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
else
  lipo -create "${THIN_BINARIES[@]}" -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi

cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
find "$ROOT_DIR/Resources" -maxdepth 1 -name '*.png' -exec cp {} "$APP_BUNDLE/Contents/Resources/" \;

if [[ -f "$ICON_SOURCE" ]]; then
  ICONSET="$BUILD_DIR/MouseRun.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/MouseRun.icns"
fi

if [[ "$MODE" == "appstore" ]]; then
  SIGN_IDENTITY="${APP_STORE_SIGN_IDENTITY:-}"
  if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null
    codesign --verify --strict --deep --verbose=2 "$APP_BUNDLE"

    if [[ -n "${APP_STORE_INSTALLER_IDENTITY:-}" ]]; then
      productbuild \
        --component "$APP_BUNDLE" /Applications \
        --sign "$APP_STORE_INSTALLER_IDENTITY" \
        "$BUILD_DIR/MouseRun.pkg"
      echo "Built App Store package: $BUILD_DIR/MouseRun.pkg"
    else
      echo "Set APP_STORE_INSTALLER_IDENTITY to create a signed .pkg for App Store Connect."
    fi
  else
    codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" --sign - "$APP_BUNDLE" >/dev/null
    echo "Built unsigned App Store test bundle: $APP_BUNDLE"
    echo "Set APP_STORE_SIGN_IDENTITY and APP_STORE_INSTALLER_IDENTITY for submission signing."
  fi
else
  SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
  codesign --force --deep --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null
fi

if [[ "$PACKAGE" == true ]]; then
  mkdir -p "$DIST_DIR"
  RELEASE_BASENAME="$APP_NAME-$VERSION+$BUILD_NUMBER"
  DMG_STAGING="$BUILD_DIR/dmg"
  DMG_PATH="$DIST_DIR/$RELEASE_BASENAME-macOS-universal.dmg"
  CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"
  RELEASE_NOTES_PATH="$DIST_DIR/RELEASE_NOTES.md"

  mkdir -p "$DMG_STAGING"
  cp -R "$APP_BUNDLE" "$DMG_STAGING/"
  ln -s /Applications "$DMG_STAGING/Applications"

  hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

  (
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$DMG_PATH")" > "$CHECKSUM_PATH"
  )

  cat > "$RELEASE_NOTES_PATH" <<EOF
# $APP_NAME $VERSION

Publisher: $PUBLISHER
GitHub: @$GITHUB_OWNER
Bundle ID: $BUNDLE_ID

## Download

Download \`$RELEASE_BASENAME-macOS-universal.dmg\`, open it, then drag \`$APP_NAME.app\` to Applications.

## Compatibility

- Intel Mac: macOS $MIN_MACOS or later
- Apple Silicon Mac: macOS 11 or later
- Recommended menu bar placement: put $APP_NAME to the right of RunCat.

## First Launch

This direct-distribution build is ad-hoc signed. If macOS says it cannot verify the developer, Control-click \`$APP_NAME.app\` in Finder and choose Open.

## Checksum

\`\`\`
$(cat "$CHECKSUM_PATH")
\`\`\`
EOF
fi

if [[ "$DO_INSTALL" == true ]]; then
  rm -rf "$INSTALL_BUNDLE"
  cp -R "$APP_BUNDLE" "$INSTALL_BUNDLE"
fi

echo "Built $APP_BUNDLE"
if [[ "$PACKAGE" == true ]]; then
  echo "Packaged:"
  echo "  $DMG_PATH"
  echo "  $CHECKSUM_PATH"
  echo "  $RELEASE_NOTES_PATH"
fi
if [[ "$DO_INSTALL" == true ]]; then
  echo "Installed $INSTALL_BUNDLE"
fi
