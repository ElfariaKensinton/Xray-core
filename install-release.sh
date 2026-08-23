#!/usr/bin/env bash
set -euo pipefail

# This installer follows the upstream XTLS/Xray-install implementation,
# but rewrites its repository references so it installs from this fork's
# GitHub Releases instead of XTLS/Xray-core.

UPSTREAM_URL='https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh'
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

curl -fsSL "$UPSTREAM_URL" -o "$TMP_FILE"

sed \
  -e 's#https://github.com/XTLS/Xray-core#https://github.com/ElfariaKensinton/Xray-core#g' \
  -e 's#https://api.github.com/repos/XTLS/Xray-core#https://api.github.com/repos/ElfariaKensinton/Xray-core#g' \
  -e 's#https://github.com/XTLS/Xray-install/raw/main/install-release.sh#https://raw.githubusercontent.com/ElfariaKensinton/Xray-core/main/install-release.sh#g' \
  -e 's#https://github.com/XTLS/Xray-install#https://github.com/ElfariaKensinton/Xray-core#g' \
  "$TMP_FILE" > "${TMP_FILE}.patched"

exec bash "${TMP_FILE}.patched" "$@"
