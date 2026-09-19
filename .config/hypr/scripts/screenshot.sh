#!/usr/bin/env bash
# Capture a screenshot, copy it to the clipboard, then notify.
#
# hyprshot backgrounds the capture and `exit`s as soon as slurp dies, which
# kills notify-send before Quickshell ever sees the popup. Do the capture
# synchronously instead. Clipboard copy prefers /tmp, then $XDG_RUNTIME_DIR
# if /tmp is full or the copy fails. A failed copy must not skip the notification.

set -uo pipefail

usage() {
    echo "Usage: $0 output|window|region" >&2
    exit 2
}

mode="${1:-}"
[[ "$mode" == "output" || "$mode" == "window" || "$mode" == "region" ]] || usage

if [[ -z "${HYPRSHOT_DIR:-}" ]]; then
    if [[ -z "${XDG_PICTURES_DIR:-}" ]] && command -v xdg-user-dir >/dev/null 2>&1; then
        XDG_PICTURES_DIR="$(xdg-user-dir PICTURES)"
    fi
    savedir="${XDG_PICTURES_DIR:-$HOME/Pictures}"
else
    savedir="$HYPRSHOT_DIR"
fi

mkdir -p "$savedir"
file="$savedir/$(date +%Y-%m-%d-%H%M%S)_hyprshot.png"

# Let Hyprland finish processing the keybind before slurp grabs the pointer.
sleep 0.1

geometry=""
case "$mode" in
    output)
        geometry="$(slurp -or)" || exit 0
        ;;
    region)
        geometry="$(slurp -d)" || exit 0
        ;;
    window)
        boxes="$(hyprctl clients -j | jq -r --argjson ids "$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')" \
            '.[] | select(.workspace.id as $w | $ids | index($w) != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
        [[ -n "$boxes" ]] || exit 0
        geometry="$(slurp -r <<<"$boxes")" || exit 0
        ;;
esac

[[ -n "$geometry" ]] || exit 0

grim -g "$geometry" "$file" || exit 1

copy_to_clipboard() {
    local src="$1"
    local need tmp_free
    need="$(stat -c %s "$src" 2>/dev/null || echo 0)"
    tmp_free="$(df -B1 --output=avail /tmp 2>/dev/null | awk 'NR==2 { print $1 }')"
    tmp_free="${tmp_free:-0}"

    if (( tmp_free > need )) && TMPDIR=/tmp wl-copy --type image/png < "$src"; then
        return 0
    fi
    TMPDIR="${XDG_RUNTIME_DIR:-/tmp}" wl-copy --type image/png < "$src"
}

copied=0
if copy_to_clipboard "$file"; then
    copied=1
fi

if [[ "$copied" -eq 1 ]]; then
    body="Image saved in ${file} and copied to the clipboard."
else
    body="Image saved in ${file}. Clipboard copy failed."
fi

notify-send -a Hyprshot -t 5000 "Screenshot saved" "$body" || true
