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
STAMP_DIR="$PROJECT_DIR/.build/bundle-stamp"
mkdir -p "$STAMP_DIR" "$APP/Contents/MacOS"

# macOS ties the Screen Recording approval to the app's signing identity, so an identity
# that changes between builds costs the user a permission prompt every single time. A
# real certificate is therefore preferred over ad-hoc, and the choice is remembered here
# rather than left to whoever happens to export LIDFOLD_SIGN_IDENTITY.
detect_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/"(Apple Development|Developer ID Application|Apple Distribution)/ { print $2; exit }'
}

IDENTITY="${LIDFOLD_SIGN_IDENTITY:-}"
[ -n "$IDENTITY" ] || IDENTITY="$(cat "$STAMP_DIR/identity" 2>/dev/null || true)"
[ -n "$IDENTITY" ] || IDENTITY="$(detect_identity)"
[ -n "$IDENTITY" ] || IDENTITY="-"

if [ "$IDENTITY" = "-" ]; then
  echo "Signing ad-hoc. Screen Recording has to be approved again after every rebuild."
fi

if [ ! -x "$APP/Contents/MacOS/LidFold" ] \
  || ! cmp -s "$BIN_PATH/LidFold" "$STAMP_DIR/executable" \
  || ! cmp -s Info.plist "$APP/Contents/Info.plist" \
  || [ "$IDENTITY" != "$(cat "$STAMP_DIR/identity" 2>/dev/null || true)" ]; then
  cp "$BIN_PATH/LidFold" "$APP/Contents/MacOS/LidFold"
  cp Info.plist "$APP/Contents/Info.plist"

  # Launching the app leaves com.apple.provenance behind, and a synced Desktop adds
  # Finder metadata of its own. codesign refuses to sign a bundle carrying either, so
  # without this the signing step fails and the app keeps a stale, invalid signature.
  # macOS then denies Screen Recording, which is hard to tell apart from a missing grant.
  /usr/bin/xattr -cr "$APP"
  /usr/bin/codesign --force --sign "$IDENTITY" --identifier com.tahsinefe.lidfold "$APP"

  # Not --strict: a synced folder re-stamps com.apple.FinderInfo on the bundle within
  # moments of it being written, and strict verification rejects that even though the
  # signature itself is sound. This still catches a signature that failed to apply.
  /usr/bin/codesign --verify "$APP"
  cp "$BIN_PATH/LidFold" "$STAMP_DIR/executable"
  printf '%s' "$IDENTITY" > "$STAMP_DIR/identity"
  echo "Rebuilt $APP, signed as: $IDENTITY"
else
  echo "Bundle already current, signed as: $IDENTITY"
fi
