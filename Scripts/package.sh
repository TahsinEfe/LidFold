#!/usr/bin/env bash
# Produces a release build, a versioned ZIP and its checksum in dist/.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

./Scripts/build.sh release

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
ARCHIVE="LidFold-$VERSION-$(uname -m).zip"

cd dist
rm -f "$ARCHIVE" SHA256SUMS.txt
/usr/bin/ditto -c -k --keepParent LidFold.app "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt

echo "Packaged dist/$ARCHIVE"
cat SHA256SUMS.txt
