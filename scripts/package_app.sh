#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
configuration="${CONFIGURATION:-debug}"
signing_identity="${SIGN_IDENTITY:--}"
local_install_path="${LOCAL_INSTALL_PATH:-}"

case "$configuration" in
  debug|release) ;;
  *)
    echo "CONFIGURATION must be debug or release." >&2
    exit 64
    ;;
esac

staging_root=$(mktemp -d "${TMPDIR:-/private/tmp}/quotabar-package.XXXXXX")
trap 'rm -rf "$staging_root"' EXIT

app_directory="$staging_root/QuotaBar.app"
contents_directory="$app_directory/Contents"
macos_directory="$contents_directory/MacOS"
resources_directory="$contents_directory/Resources"
helpers_directory="$contents_directory/Helpers"
iconset_directory="$staging_root/QuotaBar.iconset"
app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Config/Info.plist)
archive_path="$project_root/dist/QuotaBar-v${app_version}-macOS-arm64.zip"
checksum_path="$archive_path.sha256"

cd "$project_root"
swift build -c "$configuration"
swift scripts/generate_app_icon.swift

mkdir -p \
  "$macos_directory" \
  "$resources_directory" \
  "$helpers_directory" \
  "$iconset_directory" \
  "$project_root/dist"

cp Config/Info.plist "$contents_directory/Info.plist"
cp ".build/$configuration/QuotaBar" "$macos_directory/QuotaBar"
cp -R ".build/$configuration/QuotaBar_QuotaBar.bundle" "$resources_directory/"

for icon_file in Sources/QuotaBar/Resources/Assets.xcassets/AppIcon.appiconset/icon_*.png; do
  cp "$icon_file" "$iconset_directory/"
done
iconutil -c icns "$iconset_directory" -o "$resources_directory/QuotaBar.icns"

scripts/vendor_codex.sh "$helpers_directory/codex"

xattr -cr "$app_directory"

if [ "$signing_identity" = "-" ]; then
  # An ad-hoc app has no sandbox container for an inherited helper.
  codesign --force --sign - "$helpers_directory/codex"
else
  codesign --force --sign "$signing_identity" \
    --entitlements Config/Helper.entitlements \
    "$helpers_directory/codex"
fi
codesign --force --sign "$signing_identity" \
  --entitlements Config/QuotaBar.entitlements \
  "$app_directory"

codesign --verify --deep --strict "$app_directory"

rm -f "$archive_path" "$checksum_path"
ditto -c -k --norsrc --keepParent "$app_directory" "$archive_path"
(
  cd "$(dirname "$archive_path")"
  shasum -a 256 "$(basename "$archive_path")" > "$(basename "$checksum_path")"
)

if [ -n "$local_install_path" ]; then
  case "$local_install_path" in
    /*.app) ;;
    *)
      echo "LOCAL_INSTALL_PATH must be an absolute path ending in .app" >&2
      exit 64
      ;;
  esac

  rm -rf "$local_install_path"
  mkdir -p "$(dirname "$local_install_path")"
  ditto --norsrc --noextattr "$app_directory" "$local_install_path"
  codesign --verify --deep --strict "$local_install_path"
  echo "$local_install_path"
fi

echo "$archive_path"
echo "$checksum_path"
