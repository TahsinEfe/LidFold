#!/usr/bin/env bash
# Builds the app and launches it. Any previous instance is stopped first, and the launch
# deliberately omits `open -n`, so the menu bar never ends up with two icons.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

pkill -x LidFold >/dev/null 2>&1 || true
./Scripts/build.sh "${1:-debug}"
/usr/bin/open "$PROJECT_DIR/dist/LidFold.app"
