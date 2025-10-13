#!/usr/bin/env bash
set -euo pipefail

SRC=${1:-}
if [[ -z "$SRC" ]]; then
  echo "Usage: $0 path/to/1024.png"
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "sips tool not found (macOS image processing)."
  exit 1
fi

ASSET_DIR="LyricTapper/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ASSET_DIR"

cat >"$ASSET_DIR/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "size" : "16x16",  "scale" : "1x", "filename" : "16.png" },
    { "idiom" : "mac", "size" : "16x16",  "scale" : "2x", "filename" : "32.png" },
    { "idiom" : "mac", "size" : "32x32",  "scale" : "1x", "filename" : "32-1x.png" },
    { "idiom" : "mac", "size" : "32x32",  "scale" : "2x", "filename" : "64.png" },
    { "idiom" : "mac", "size" : "128x128","scale" : "1x", "filename" : "128.png" },
    { "idiom" : "mac", "size" : "128x128","scale" : "2x", "filename" : "256.png" },
    { "idiom" : "mac", "size" : "256x256","scale" : "1x", "filename" : "256-1x.png" },
    { "idiom" : "mac", "size" : "256x256","scale" : "2x", "filename" : "512.png" },
    { "idiom" : "mac", "size" : "512x512","scale" : "1x", "filename" : "512-1x.png" },
    { "idiom" : "mac", "size" : "512x512","scale" : "2x", "filename" : "1024.png" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
JSON

# Generate sizes
sips -z 16 16   "$SRC" --out "$ASSET_DIR/16.png" >/dev/null
sips -z 32 32   "$SRC" --out "$ASSET_DIR/32.png" >/dev/null
sips -z 32 32   "$SRC" --out "$ASSET_DIR/32-1x.png" >/dev/null
sips -z 64 64   "$SRC" --out "$ASSET_DIR/64.png" >/dev/null
sips -z 128 128 "$SRC" --out "$ASSET_DIR/128.png" >/dev/null
sips -z 256 256 "$SRC" --out "$ASSET_DIR/256.png" >/dev/null
sips -z 256 256 "$SRC" --out "$ASSET_DIR/256-1x.png" >/dev/null
sips -z 512 512 "$SRC" --out "$ASSET_DIR/512.png" >/dev/null
sips -z 512 512 "$SRC" --out "$ASSET_DIR/512-1x.png" >/dev/null
cp "$SRC" "$ASSET_DIR/1024.png"

echo "AppIcon assets updated in $ASSET_DIR"


