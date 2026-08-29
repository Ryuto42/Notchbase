#!/bin/bash
# Builds a Release .app and zips it for a GitHub release.
#
#   Scripts/package.sh                 # ad-hoc signed, fine for personal use
#   SIGN_IDENTITY="Developer ID Application: You (TEAMID)" Scripts/package.sh
#
# Notarising (optional, removes the Gatekeeper warning for other people):
#   xcrun notarytool submit dist/Notchbase-<version>.zip \
#       --keychain-profile notchbase --wait
#   xcrun stapler staple dist/Notchbase.app
#
# The zip is signed with the Sparkle EdDSA key held in the login keychain and
# appcast.xml at the repo root is regenerated. Commit it and attach the zip to a
# GitHub release tagged v<version>. Set SKIP_APPCAST=1 to build only.
set -euo pipefail

SPARKLE_VERSION=2.9.6
PROJECT_URL="https://github.com/Ryuto42/Notchbase"
RELEASE_URL_PREFIX="$PROJECT_URL/releases/download"

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/.build/release"
dist="$root/dist"
rm -rf "$build" "$dist"
mkdir -p "$dist"

args=(-project "$root/Notchbase.xcodeproj" -scheme Notchbase -configuration Release
      -derivedDataPath "$build" -skipPackagePluginValidation)

if [ -n "${SIGN_IDENTITY:-}" ]; then
    args+=(CODE_SIGN_IDENTITY="$SIGN_IDENTITY" CODE_SIGN_STYLE=Manual)
    echo "Signing with: $SIGN_IDENTITY"
else
    echo "No SIGN_IDENTITY set — building ad-hoc signed."
fi

xcodebuild "${args[@]}" build

app="$build/Build/Products/Release/Notchbase.app"
[ -d "$app" ] || { echo "Build produced no app bundle"; exit 1; }

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
cp -R "$app" "$dist/"
# ditto keeps the bundle's symlinks and extended attributes intact.
ditto -c -k --keepParent "$dist/Notchbase.app" "$dist/Notchbase-$version.zip"

codesign -dv "$dist/Notchbase.app" 2>&1 | grep -E "Signature|TeamIdentifier" || true

# --- Sparkle appcast -------------------------------------------------------
# Signs the zip with the EdDSA key in the login keychain and refreshes appcast.xml,
# which is what the app polls for updates. Skipped with SKIP_APPCAST=1.
tools="$root/.build/sparkle-tools"
if [ -z "${SKIP_APPCAST:-}" ]; then
    if [ ! -x "$tools/bin/generate_appcast" ]; then
        echo "Fetching Sparkle $SPARKLE_VERSION tools…"
        mkdir -p "$tools"
        curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
            | tar xJ -C "$tools"
    fi

    rm -rf "$dist/Notchbase.app"
    cp "$root/appcast.xml" "$dist/appcast.xml" 2>/dev/null || true
    "$tools/bin/generate_appcast" \
        --download-url-prefix "$RELEASE_URL_PREFIX/v$version/" \
        --link "$PROJECT_URL" \
        -o "$dist/appcast.xml" \
        "$dist"
    cp "$dist/appcast.xml" "$root/appcast.xml"
    echo "appcast.xml updated"
fi

echo
echo "dist/Notchbase-$version.zip"
