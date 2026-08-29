#!/bin/bash
# Cuts a release and hands it to everyone already running Notchbase.
#
#   Scripts/release.sh 0.2.0
#   Scripts/release.sh 0.2.0 --notes "What changed"
#
# Bumps the version, builds and signs, publishes the GitHub release, then commits
# and pushes the appcast that installed copies poll.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

version="${1:-}"
[ -n "$version" ] || { echo "usage: Scripts/release.sh <version> [--notes TEXT]"; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3"; exit 1; }

notes=""
if [ "${2:-}" = "--notes" ]; then notes="${3:-}"; fi

repo="Ryuto42/Notchbase"
tag="v$version"

# --- guards ---------------------------------------------------------------
[ -z "$(git status --porcelain)" ] || { echo "Working tree is dirty. Commit or stash first."; exit 1; }
git rev-parse "$tag" >/dev/null 2>&1 && { echo "$tag already exists."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Run: gh auth login"; exit 1; }
gh repo view "$repo" >/dev/null 2>&1 || { echo "$repo does not exist yet."; exit 1; }

previous=$(git tag --list 'v*' --sort=-v:refname | head -1)

# --- bump -----------------------------------------------------------------
build=$(( $(git rev-list --count HEAD) + 1 ))
/usr/bin/sed -i '' \
    -e "s/MARKETING_VERSION = .*/MARKETING_VERSION = $version;/" \
    -e "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $build;/" \
    Notchbase.xcodeproj/project.pbxproj
echo "→ $version (build $build)"

# --- build, sign, appcast -------------------------------------------------
Scripts/package.sh
zip="dist/Notchbase-$version.zip"
[ -f "$zip" ] || { echo "package.sh produced no $zip"; exit 1; }
grep -q "sparkle:edSignature" appcast.xml || { echo "appcast.xml is unsigned"; exit 1; }
grep -q "$tag/Notchbase-$version.zip" appcast.xml || { echo "appcast.xml does not point at $tag"; exit 1; }

# --- publish --------------------------------------------------------------
# The release has to exist before the appcast naming its asset is pushed, or an
# app that checks in between downloads a 404.
git add Notchbase.xcodeproj/project.pbxproj appcast.xml
git commit -q -m "Release $version"
git tag "$tag"
git push -q origin main
git push -q origin "$tag"

if [ -n "$notes" ]; then
    gh release create "$tag" "$zip" --repo "$repo" --title "$version" --notes "$notes"
else
    gh release create "$tag" "$zip" --repo "$repo" --title "$version" --generate-notes
fi

echo
echo "Released $version."
echo "Installed copies pick it up within 6 hours, or immediately from Check for Updates."
[ -n "$previous" ] && echo "Previous release was $previous."
