#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SVG="$ROOT/Support/FocoViewIcon.svg"
PNG="$ROOT/Support/FocoViewIcon.png"
ICNS="$ROOT/Support/ViewerIcon.icns"
ICONSET="${TMPDIR:-/tmp}/FocoView-$RANDOM.iconset"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -s format png "$SVG" --out "$PNG" >/dev/null

make_icon() {
    local pixels="$1"
    local name="$2"
    sips -z "$pixels" "$pixels" "$PNG" --out "$ICONSET/$name" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
cp "$PNG" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

echo "Generated $PNG and $ICNS"
