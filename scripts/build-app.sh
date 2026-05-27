#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building debug binaries…"
swift build -c debug --product Sudylko
swift build -c debug --product SudylkoDockTilePlugin

BIN="$ROOT/.build/debug/Sudylko"
PLUGIN_LIB="$ROOT/.build/debug/libSudylkoDockTilePlugin.dylib"
APP="$ROOT/Sudylko.app"
BUILD_NUMBER="$(date +%Y%m%d%H%M%S)"

if [[ ! -f "$BIN" ]]; then
  echo "error: binary not found at $BIN" >&2
  exit 1
fi
if [[ ! -f "$PLUGIN_LIB" ]]; then
  echo "error: dock tile plug-in not found at $PLUGIN_LIB" >&2
  exit 1
fi

echo "Assembling Sudylko.app (build $BUILD_NUMBER)…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp App/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/Sudylko"
chmod +x "$APP/Contents/MacOS/Sudylko"

PLUGIN_DST="$APP/Contents/PlugIns/SudylkoDockTile.docktileplugin"
mkdir -p "$PLUGIN_DST/Contents/MacOS"
cp "$ROOT/App/SudylkoDockTile/Info.plist" "$PLUGIN_DST/Contents/Info.plist"
cp "$PLUGIN_LIB" "$PLUGIN_DST/Contents/MacOS/SudylkoDockTile"
chmod +x "$PLUGIN_DST/Contents/MacOS/SudylkoDockTile"

echo "Regenerating AppIcon.icns (same artwork as dock, no inner margin)…"
chmod +x "$ROOT/scripts/generate-app-icon.sh"
SUDYLKO_BIN="$BIN" "$ROOT/scripts/generate-app-icon.sh"
cp "$ROOT/App/Icon.icns" "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"

touch "$APP"

echo "Done: $APP"
echo "Quit any running Sudylko, then:"
echo "  open -n \"$APP\""

killall Sudylko 2>/dev/null || true
open -n "$APP"
