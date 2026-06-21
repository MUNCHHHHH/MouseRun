#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_DIR="$(dirname "$ROOT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$BUILD_DIR/MouseRun.app"
INSTALL_BUNDLE="/Applications/MouseRun.app"
ICON_SOURCE="$ROOT_DIR/Resources/AppIconTransparent.png"
if [[ ! -f "$ICON_SOURCE" ]]; then
  ICON_SOURCE="$WORKSPACE_DIR/앱 아이콘 사진.png"
fi

APP_NAME="MouseRun"
BUNDLE_ID="com.munch.mouserun"
PUBLISHER="MUNCH"
GITHUB_OWNER="MUNCHHHHH"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/Resources/Info.plist")"
MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$ROOT_DIR/Resources/Info.plist")"
ARCHS=(${=ARCHS:-arm64 x86_64})
DO_INSTALL=false

usage() {
  cat <<EOF
Usage: ./build.sh [--install] [--no-package]

Builds a direct-distribution macOS release in dist/.

Options:
  --install      Also copy the built app to /Applications.
  --no-package  Build the app bundle only.

Environment:
  ARCHS="arm64"              Build only selected architectures.
  CODESIGN_IDENTITY="Name"   Sign with a certificate instead of ad-hoc signing.
EOF
}

PACKAGE=true
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

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

THIN_BINARIES=()
for arch in "${ARCHS[@]}"; do
  THIN_BINARY="$BUILD_DIR/$APP_NAME-$arch"
  swiftc \
    -target "$arch-apple-macosx$MIN_MACOS" \
    -framework Cocoa \
    -framework IOBluetooth \
    "$ROOT_DIR/Sources/main.swift" \
    -o "$THIN_BINARY"
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

SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null

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

- macOS $MIN_MACOS or later
- Apple Silicon and Intel Macs
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
