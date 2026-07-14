#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${1:-debug}"
APP="$HOME/Applications/Foco View.app"

cd "$ROOT"
if [[ ! -f "$ROOT/Support/ViewerIcon.icns" || "$ROOT/Support/FocoViewIcon.svg" -nt "$ROOT/Support/ViewerIcon.icns" ]]; then
    "$ROOT/Scripts/generate-viewer-icon.sh"
fi

swift build -c "$CONFIGURATION" --product FocoView
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FocoView" "$APP/Contents/MacOS/FocoView"
cp "$ROOT/Support/FocoView-Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Support/ViewerIcon.icns" "$APP/Contents/Resources/ViewerIcon.icns"
cp "$ROOT/Support/FocoViewIcon.png" "$APP/Contents/Resources/FocoViewIcon.png"

chmod +x "$APP/Contents/MacOS/FocoView"
codesign --force --deep --sign - "$APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$APP"

echo "Installed and registered $APP"
echo "Foco View is now available in Finder's Open With menu for .bulb files."
