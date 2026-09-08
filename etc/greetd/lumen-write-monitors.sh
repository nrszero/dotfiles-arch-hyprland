#!/bin/bash
set -euo pipefail

DEST="/etc/greetd/monitors.lua"
TMP="$(mktemp "${DEST}.XXXXXX")"

cleanup() {
    rm -f "$TMP"
}
trap cleanup EXIT

cat > "$TMP"

if ! grep -q '^return {' "$TMP"; then
    echo "lumen-write-monitors: input must start with 'return {'" >&2
    exit 1
fi

chmod 644 "$TMP"
mv "$TMP" "$DEST"
trap - EXIT
