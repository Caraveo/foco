#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${1:-debug}"
APP="$HOME/Applications/Foco.app"

cd "$ROOT"
swift build -c "$CONFIGURATION" --product Foco
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
rm -rf "$APP/Foco_Foco.bundle"
cp "$BIN_DIR/Foco" "$APP/Contents/MacOS/Foco"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Sources/Foco/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Sources/Foco/Resources/BulbIcon.png" "$APP/Contents/Resources/BulbIcon.png"

chmod +x "$APP/Contents/MacOS/Foco"
codesign --force --deep --sign - "$APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$APP"

echo "Installed and registered $APP"
echo "Finder now associates .bulb files with Foco."
