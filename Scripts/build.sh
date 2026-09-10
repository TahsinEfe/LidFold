#!/usr/bin/env bash
# Builds LidFold and assembles dist/LidFold.app.
#
# The bundle is left untouched when nothing changed. Re-signing gives the app a new
# code identity, which makes macOS forget the Screen Recording approval and forces the
# user through the permission dialog again.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

CONFIGURATION="${1:-debug}"
case "$CONFIGURATION" in
  debug|release) ;;
  *) echo "usage: $0 [debug|release]" >&2; exit 2 ;;
esac

swift build -c "$CONFIGURATION"
BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"
APP="$PROJECT_DIR/dist/LidFold.app"
STAMP="$PROJECT_DIR/.build/bundled-executable"

mkdir -p "$APP/Contents/MacOS"

if [ -n "${LIDFOLD_SIGN_IDENTITY:-}" ] \
  || [ ! -x "$APP/Contents/MacOS/LidFold" ] \
  || ! cmp -s "$BIN_PATH/LidFold" "$STAMP" \
  || ! cmp -s Info.plist "$APP/Contents/Info.plist"; then
  cp "$BIN_PATH/LidFold" "$APP/Contents/MacOS/LidFold"
  cp Info.plist "$APP/Contents/Info.plist"
  /usr/bin/codesign --force --sign "${LIDFOLD_SIGN_IDENTITY:--}" --identifier com.tahsinefe.lidfold "$APP"
  cp "$BIN_PATH/LidFold" "$STAMP"
  echo "Rebuilt $APP"
else
  echo "Bundle already current: $APP"
fi
