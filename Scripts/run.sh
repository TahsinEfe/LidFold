#!/usr/bin/env bash
# Builds the app and launches it. Any previous instance is stopped first so the menu
# bar does not end up with two icons.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

pkill -x LidFold >/dev/null 2>&1 || true
./Scripts/build.sh "${1:-debug}"
/usr/bin/open -n "$PROJECT_DIR/dist/LidFold.app"
