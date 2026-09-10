#!/usr/bin/env bash
# Everything that can be verified without a lid, a display or a permission prompt:
# the unit tests, then the shader checks against a generated source image.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

swift build
swift test

BIN_PATH="$(swift build --show-bin-path)"
"$BIN_PATH/LidFold" --preview
