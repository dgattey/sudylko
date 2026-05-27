#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/App/AppIcon.iconset"
OUT="$ROOT/App/Icon.icns"
BIN="${SUDYLKO_BIN:-}"

if [[ -z "$BIN" || ! -x "$BIN" ]]; then
  echo "error: set SUDYLKO_BIN to the built Sudylko binary" >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

echo "Rendering app icon via DockIconRenderer…"
SUDYLKO_EXPORT_ICONSET="$ICONSET" "$BIN"

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Icon: $OUT"
