#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="${1:-0.0.1}"
DIST="$ROOT/dist"
# Stage app bundles outside any iCloud-synced folder so codesign is not
# tripped by File Provider re-stamping FinderInfo/resource-fork detritus.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
BIN_DIR=""

cd "$ROOT"
swift build -c release --product Foco --product FocoView
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$DIST"
mkdir -p "$STAGE/Foco.app/Contents/MacOS" "$STAGE/Foco.app/Contents/Resources"
mkdir -p "$STAGE/Foco View.app/Contents/MacOS" "$STAGE/Foco View.app/Contents/Resources"

cp "$BIN_DIR/Foco" "$STAGE/Foco.app/Contents/MacOS/Foco"
cp "$ROOT/Support/Info.plist" "$STAGE/Foco.app/Contents/Info.plist"
cp "$ROOT/Sources/Foco/Resources/AppIcon.icns" "$STAGE/Foco.app/Contents/Resources/AppIcon.icns"
cp "$ROOT/Sources/Foco/Resources/BulbIcon.png" "$STAGE/Foco.app/Contents/Resources/BulbIcon.png"

cp "$BIN_DIR/FocoView" "$STAGE/Foco View.app/Contents/MacOS/FocoView"
cp "$ROOT/Support/FocoView-Info.plist" "$STAGE/Foco View.app/Contents/Info.plist"
cp "$ROOT/Support/ViewerIcon.icns" "$STAGE/Foco View.app/Contents/Resources/ViewerIcon.icns"
cp "$ROOT/Support/FocoViewIcon.png" "$STAGE/Foco View.app/Contents/Resources/FocoViewIcon.png"

chmod +x "$STAGE/Foco.app/Contents/MacOS/Foco"
chmod +x "$STAGE/Foco View.app/Contents/MacOS/FocoView"
codesign --force --deep --sign - "$STAGE/Foco.app"
codesign --force --deep --sign - "$STAGE/Foco View.app"
codesign --verify --deep --strict "$STAGE/Foco.app"
codesign --verify --deep --strict "$STAGE/Foco View.app"

mkdir -p "$DIST"
ditto -c -k --sequesterRsrc --keepParent "$STAGE/Foco.app" "$DIST/Foco-macOS-v$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$STAGE/Foco View.app" "$DIST/Foco-View-macOS-v$VERSION.zip"

echo "Built release archives:"
echo "$DIST/Foco-macOS-v$VERSION.zip"
echo "$DIST/Foco-View-macOS-v$VERSION.zip"
