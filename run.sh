#!/usr/bin/env bash
set -euo pipefail

# Simple macOS build-and-run helper for LyricTapper
# Usage:
#   ./run.sh [--scheme LyricTapper] [--config Debug|Release] [--clean]

SCHEME="LyricTapper"
CONFIG="Debug"
CLEAN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      SCHEME="${2:-$SCHEME}"; shift 2;;
    --config)
      CONFIG="${2:-$CONFIG}"; shift 2;;
    --clean)
      CLEAN="clean"; shift;;
    *)
      echo "Unknown option: $1"; exit 1;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# Find the Xcode project (prefer LyricTapper.xcodeproj)
PROJECT_FILE=""
if [[ -d "LyricTapper.xcodeproj" ]]; then
  PROJECT_FILE="LyricTapper.xcodeproj"
else
  PROJECT_FILE="$(find . -maxdepth 2 -type d -name "*.xcodeproj" | head -n1 | sed 's#^\./##')"
fi

if [[ -z "$PROJECT_FILE" || ! -d "$PROJECT_FILE" ]]; then
  echo "No .xcodeproj found. Open this folder in Xcode and create the LyricTapper app target first."
  exit 1
fi

DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
mkdir -p "$DERIVED_DATA_PATH"

echo "Building scheme=$SCHEME config=$CONFIG project=$PROJECT_FILE"
if command -v xcpretty >/dev/null 2>&1; then
  set +e
  xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration "$CONFIG" -derivedDataPath "$DERIVED_DATA_PATH" -destination 'platform=macOS' $CLEAN build | xcpretty
  STATUS=${PIPESTATUS[0]}
  set -e
  if [[ $STATUS -ne 0 ]]; then
    echo "xcodebuild failed ($STATUS). See logs above."
    exit $STATUS
  fi
else
  xcodebuild -project "$PROJECT_FILE" -scheme "$SCHEME" -configuration "$CONFIG" -derivedDataPath "$DERIVED_DATA_PATH" -destination 'platform=macOS' $CLEAN build
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIG/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
  # fallback: try to find any .app in products
  APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products/$CONFIG" -maxdepth 2 -type d -name "*.app" | head -n1)"
fi

if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "Build completed, but could not locate .app in Build/Products/$CONFIG."
  echo "Check build logs above for errors and ensure the scheme ($SCHEME) builds an app."
  exit 1
fi

echo "Launching: $APP_PATH"
open "$APP_PATH"


