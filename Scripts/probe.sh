#!/usr/bin/env bash
# Reports whether this Mac exposes a readable lid angle sensor. Exits non-zero when it
# does not, which is the quickest way to tell an unsupported model from a broken build.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

swift build
"$(swift build --show-bin-path)/LidFold" --probe
