#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="${SCHEME:-Sudylko}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=latest}"
DERIVED="${DERIVED:-$ROOT/.build/DerivedData-iOS}"

echo "Building $SCHEME for $DESTINATION…"
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  build

echo "Done. Open the package in Xcode and run the Sudylko scheme on an iOS simulator,"
echo "or locate the built .app under: $DERIVED"
