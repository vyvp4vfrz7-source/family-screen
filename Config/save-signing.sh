#!/bin/sh
# One-time setup: keeps your Team and bundle ID in Config/Local.xcconfig
# (not tracked by git), so pulls and branch switches no longer reset them.
# Then moves this folder to the latest main branch.
# Run from Terminal inside the repo:  sh Config/save-signing.sh
set -e
cd "$(git rev-parse --show-toplevel)"
P=FamilyScreen.xcodeproj/project.pbxproj
S=Config/Signing.xcconfig
L=Config/Local.xcconfig

find_value() { # $1 = setting name; prints the first real value found
  grep -h "$1 = " "$P" "$S" "$L" 2>/dev/null \
    | grep -v 'inherited\|example\|\.share' \
    | sed "s/.*$1 = //; s/[;\"]//g; s/ *$//" | grep -v '^$' | head -1
}

TEAM=$(find_value DEVELOPMENT_TEAM)
BUNDLE=$(find_value PRODUCT_BUNDLE_IDENTIFIER)

if [ -z "$TEAM" ]; then
  echo "No Team found. In Xcode pick your Team for the FamilyScreen target"
  echo "(Signing & Capabilities), quit Xcode, then run this again."
  exit 1
fi
if [ -z "$BUNDLE" ]; then
  BUNDLE="com.$(whoami | tr -cd 'a-z0-9').familyscreen"
fi

printf '// Your own signing settings. Not shared on GitHub.\nDEVELOPMENT_TEAM = %s\nPRODUCT_BUNDLE_IDENTIFIER = %s\n' "$TEAM" "$BUNDLE" > "$L"
echo "Saved Team $TEAM and bundle ID $BUNDLE in $L"

# Drop Xcode's local edits to the project file, then get the latest main.
git checkout -- "$P" "$S"
git fetch origin
git checkout main
git pull --ff-only origin main
echo "Done. Open FamilyScreen.xcodeproj and press Run."
