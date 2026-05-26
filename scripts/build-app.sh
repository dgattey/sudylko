#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building debug binary…"
swift build -c debug

BIN="$ROOT/.build/debug/Sudylko"
ICON_BIN="$ROOT/.build/debug/SudylkoIconExport"
APP="$ROOT/Sudylko.app"
BUILD_NUMBER="$(date +%Y%m%d%H%M%S)"

if [[ ! -f "$BIN" ]]; then
  echo "error: binary not found at $BIN" >&2
  exit 1
fi

echo "Assembling Sudylko.app (build $BUILD_NUMBER)…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp App/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/App/Icon.icns" ]]; then
  cp "$ROOT/App/Icon.icns" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"
fi
cp "$BIN" "$APP/Contents/MacOS/Sudylko"
chmod +x "$APP/Contents/MacOS/Sudylko"
touch "$APP"

echo "Generating app icon (masked, matched to bundle)…"
chmod +x "$ROOT/scripts/generate-app-icon.sh"
SUDYLKO_BIN="$ICON_BIN" SUDYLKO_ICON_MASK_BUNDLE="$APP" "$ROOT/scripts/generate-app-icon.sh"
cp "$ROOT/App/Icon.icns" "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"

echo "Done: $APP"
echo "Quit any running Sudylko, then:"
echo "  open -n \"$APP\""

killall Sudylko 2>/dev/null || true
open -n "$APP"
