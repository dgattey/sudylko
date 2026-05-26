#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/relaunch-mac.sh"
"$ROOT/scripts/relaunch-ios.sh"
