#!/bin/sh
# Copies the home-clock web pages into WebPages/, which is bundled inside the app.
# The app shows them offline and on first launch. When online it loads the newest
# version from the live site, so you only need to run this before an App Store build.
#
# Usage (on the Mac, from the family-screen folder):
#   sh tools/sync-web-pages.sh ../home-clock
set -e
SRC="${1:-../home-clock}"
DEST="$(dirname "$0")/../WebPages"
[ -f "$SRC/index.html" ] || { echo "No index.html in $SRC"; exit 1; }
rm -rf "$DEST"
mkdir -p "$DEST/parents"
cp "$SRC"/*.html "$SRC"/*.js "$SRC"/*.json "$SRC"/*.svg "$DEST"/
cp "$SRC"/parents/*.html "$SRC"/parents/*.json "$DEST/parents/" 2>/dev/null || true
echo "Copied $(find "$DEST" -type f | wc -l | tr -d ' ') files into WebPages/"
