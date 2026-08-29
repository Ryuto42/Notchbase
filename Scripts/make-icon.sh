#!/bin/bash
# Generates every AppIcon slot from a single 1024x1024 PNG.
#
#   Scripts/make-icon.sh path/to/icon-1024.png
set -euo pipefail

src="${1:?usage: make-icon.sh <1024x1024 png>}"
out="$(dirname "$0")/../Notchbase/Resources/Assets.xcassets/AppIcon.appiconset"

for spec in "16 1" "16 2" "32 1" "32 2" "128 1" "128 2" "256 1" "256 2" "512 1" "512 2"; do
    read -r size scale <<< "$spec"
    px=$((size * scale))
    suffix=""
    [ "$scale" = "2" ] && suffix="@2x"
    sips -z "$px" "$px" "$src" --out "$out/icon_${size}x${size}${suffix}.png" >/dev/null
done

echo "Wrote $(ls "$out"/*.png | wc -l | tr -d ' ') icon files to $out"
