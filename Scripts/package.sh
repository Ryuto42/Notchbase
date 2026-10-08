#!/bin/bash
# Scripts/package.sh [SKIP_APPCAST=1]  — build, sign, zip, refresh appcast.xml
set -euo pipefail

SPARKLE_VERSION=2.9.6
SPARKLE_SHA256=52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192
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
ditto -c -k --keepParent "$dist/Notchbase.app" "$dist/Notchbase-$version.zip"

codesign -dv "$dist/Notchbase.app" 2>&1 | grep -E "Signature|TeamIdentifier" || true

tools="$root/.build/sparkle-tools"
sparkle_archive="$root/.build/Sparkle-$SPARKLE_VERSION.tar.xz"
if [ -z "${SKIP_APPCAST:-}" ]; then
    if [ ! -f "$sparkle_archive" ]; then
        echo "Fetching Sparkle $SPARKLE_VERSION tools…"
        curl -fsSL -o "$sparkle_archive.part" \
            "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
        mv "$sparkle_archive.part" "$sparkle_archive"
    fi
    # Verified on every run, cached or not; the tools are always re-extracted from the verified archive.
    echo "$SPARKLE_SHA256  $sparkle_archive" | shasum -a 256 -c - >/dev/null \
        || { echo "Sparkle archive checksum mismatch"; rm -f "$sparkle_archive"; exit 1; }
    rm -rf "$tools"
    mkdir -p "$tools"
    tar xJf "$sparkle_archive" -C "$tools"

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
echo "SHA-256: $(shasum -a 256 "$dist/Notchbase-$version.zip" | awk '{print $1}')"
