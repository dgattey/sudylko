#!/usr/bin/env bash
# Build Sudylko for iOS Simulator, install on simulator, launch com.sudylko.ios.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="${SCHEME:-Sudylko}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5}"
DERIVED="${DERIVED:-$ROOT/.build/DerivedData-iOS}"
BUNDLE_ID="${BUNDLE_ID:-com.sudylko.ios}"
SIM_UDID="${SIM_UDID:-ECA79737-94F1-436F-B8A0-65DDEE942700}"
SIM_NAME="${SIM_NAME:-iPhone 17 Pro (iOS 26.5)}"

echo "Building $SCHEME for $DESTINATION..."
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED" \
  -configuration Debug \
  build

PRODUCTS="$DERIVED/Build/Products/Debug-iphonesimulator"
APP="$PRODUCTS/Sudylko.app"

if [[ ! -d "$APP" ]]; then
  BIN="$PRODUCTS/Sudylko"
  if [[ ! -f "$BIN" ]]; then
    echo "error: no Sudylko.app or Sudylko binary under $PRODUCTS" >&2
    exit 1
  fi
  echo "Wrapping binary into .app using iOS/Info.plist..."
  APP="$ROOT/.build/Sudylko-iOS-Simulator.app"
  rm -rf "$APP"
  mkdir -p "$APP"
  cp "$ROOT/iOS/Info.plist" "$APP/Info.plist"
  cp "$BIN" "$APP/Sudylko"
  chmod +x "$APP/Sudylko"
fi

boot_sim() {
  local line state
  line="$(xcrun simctl list devices | grep "$SIM_UDID" | head -1 || true)"
  if [[ -z "$line" ]]; then
    echo "error: simulator UDID $SIM_UDID not found" >&2
    exit 1
  fi
  if [[ "$line" == *"(Booted)"* ]]; then
    state=Booted
  else
    state=Shutdown
  fi
  if [[ "$state" != "Booted" ]]; then
    echo "Booting simulator $SIM_NAME ($SIM_UDID)..."
    xcrun simctl boot "$SIM_UDID"
  fi
  open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" 2>/dev/null || open -a Simulator
}

boot_sim

echo "Installing $APP on $SIM_UDID..."
xcrun simctl install "$SIM_UDID" "$APP"

echo "Launching $BUNDLE_ID..."
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"

echo "Done: $BUNDLE_ID on $SIM_NAME"
