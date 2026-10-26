#!/usr/bin/env bash
# One-time: create the EdDSA key pair Sparkle uses to sign app updates.
#
# The PRIVATE key is stored in your login keychain under an account named after the bundle ID in DylApp.toml (never
# leaves this machine, never committed). It must not use Sparkle's default `ed25519` account: every app on the Mac
# shares that one, and release-kit's appcast never signs from it.
# The PUBLIC key is written to sparkle-public-key.txt, which IS committed and gets baked
# into the app's Info.plist (SUPublicEDKey) by release-kit so the updater can verify downloads.
#
# CI signs with the same key: export it once with `generate_keys --account <bundle-id> -x sparkle_ed.key`, paste that
# file's contents into the repo's SPARKLE_ED_PRIVATE_KEY_BASE64 Actions secret, then delete the file.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/sparkle-public-key.txt"

GK="$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_keys"
if [[ ! -x "$GK" ]]; then
  echo "generate-sparkle-key: $GK not found. Run 'swift build' first." >&2
  exit 1
fi

ACCOUNT="$(awk '/^\[/ { section = $0 } section == "[app]" && /^bundle-id *=/ { gsub(/^[^"]*"|".*$/, ""); print; exit }' "$ROOT/DylApp.toml")"
if [[ -z "$ACCOUNT" ]]; then
  echo "generate-sparkle-key: no [app] bundle-id in DylApp.toml" >&2
  exit 1
fi

# Idempotent: creates the keychain private key only if the account does not already hold one.
"$GK" --account "$ACCOUNT" >/dev/null

PUB="$("$GK" --account "$ACCOUNT" -p | tr -d '[:space:]')"
if [[ -z "$PUB" ]]; then
  echo "generate-sparkle-key: could not read the public key from keychain account $ACCOUNT" >&2
  exit 1
fi

printf '%s\n' "$PUB" >"$OUT"
echo "Wrote public key from keychain account $ACCOUNT -> $OUT"
echo "  $PUB"
echo
echo "Next: commit sparkle-public-key.txt, then export the private key for CI:"
echo "  $GK --account $ACCOUNT -x sparkle_ed.key   # paste into the SPARKLE_ED_PRIVATE_KEY_BASE64 secret, then rm sparkle_ed.key"
