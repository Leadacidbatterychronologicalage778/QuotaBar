#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$project_root/Config/Info.plist")
tag="v$version"
archive="$project_root/dist/QuotaBar-$tag-macOS-arm64.zip"
checksum="$archive.sha256"

cd "$project_root"

gh auth status >/dev/null
CONFIGURATION=release scripts/package_app.sh

if gh release view "$tag" >/dev/null 2>&1; then
  echo "GitHub Release $tag already exists." >&2
  exit 1
fi

gh release create "$tag" \
  "$archive" \
  "$checksum" \
  --title "QuotaBar $tag" \
  --notes-file CHANGELOG.md

echo "https://github.com/RoketrP/QuotaBar/releases/tag/$tag"
