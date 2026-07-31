#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: scripts/vendor_codex.sh /absolute/destination/codex" >&2
  exit 64
fi

destination="$1"
expected_version="${CODEX_VERSION:-0.136.0}"

if [ -n "${CODEX_BINARY_PATH:-}" ] && [ -x "${CODEX_BINARY_PATH}" ]; then
  source_binary="${CODEX_BINARY_PATH}"
elif [ -x "/opt/homebrew/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex" ]; then
  source_binary="/opt/homebrew/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-arm64/vendor/aarch64-apple-darwin/bin/codex"
elif [ -x "/usr/local/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-x64/vendor/x86_64-apple-darwin/bin/codex" ]; then
  source_binary="/usr/local/lib/node_modules/@openai/codex/node_modules/@openai/codex-darwin-x64/vendor/x86_64-apple-darwin/bin/codex"
else
  echo "Codex native binary not found. Install it with: npm install -g @openai/codex" >&2
  exit 1
fi

actual_version=$("$source_binary" --version)
if [ "$actual_version" != "codex-cli $expected_version" ]; then
  echo "Expected codex-cli $expected_version, found: $actual_version" >&2
  echo "Install the pinned version with: npm install -g @openai/codex@$expected_version" >&2
  exit 1
fi

destination_directory=$(dirname "$destination")
mkdir -p "$destination_directory"

if [ -f "$destination" ] && cmp -s "$source_binary" "$destination"; then
  chmod 755 "$destination"
  exit 0
fi

install -m 755 "$source_binary" "$destination"
