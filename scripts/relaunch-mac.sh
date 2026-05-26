#!/usr/bin/env bash
# Rebuild debug Sudylko.app, quit running instance, launch fresh (open -n).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/build-app.sh"
