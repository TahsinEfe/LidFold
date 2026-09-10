#!/usr/bin/env bash
# Reports whether Screen Recording is granted for the app bundle.
#
# The app is started through `open` on purpose: run the executable directly and macOS
# attributes the request to the terminal, which usually has its own grant and hides the
# problem. The answer is written next to the bundle because stdout is lost that way.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

./Scripts/build.sh
rm -f dist/capture-check.txt
/usr/bin/open -n -W dist/LidFold.app --args --capture-check || true
cat dist/capture-check.txt
grep -q '^PASS:' dist/capture-check.txt
