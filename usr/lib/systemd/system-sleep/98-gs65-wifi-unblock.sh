#!/bin/bash
# After S3 resume on the GS65 Stealth 9SE, the EC asserts airplane mode while
# leaving 0x2e bit 3 set. Replay a double Fn+F10 (clear bit 3, then set it)
# so Intel Wi-Fi is no longer hard-blocked.
# https://wiki.archlinux.org/title/MSI_GS65
#
# systemd 261 only runs hooks from /usr/lib/systemd/system-sleep/.
# install.sh installs this file to that path.
set -u

TAG=gs65-wifi-unblock
EC=/sys/kernel/debug/ec/ec0/io
RADIO_BIT=$((0x08))
PRODUCT_FILE=/sys/class/dmi/id/product_name

log() {
    logger -t "$TAG" -- "$*"
    printf '%s: %s\n' "$TAG" "$*" >/dev/kmsg 2>/dev/null || true
}

log "invoked args=${1:-} ${2:-}"

[[ "${1:-}" == "post" ]] || exit 0

product=""
[[ -r "$PRODUCT_FILE" ]] && product=$(tr -d '\n' <"$PRODUCT_FILE")
if [[ "$product" != "GS65 Stealth 9SE" ]]; then
    log "skip: DMI product='$product'"
    exit 0
fi

wifi_hard_blocked() {
    local dir
    for dir in /sys/class/rfkill/rfkill*; do
        [[ -f "$dir/type" && -f "$dir/hard" ]] || continue
        [[ $(<"$dir/type") == wlan ]] || continue
        [[ $(<"$dir/hard") == 1 ]] && return 0
    done
    return 1
}

readbyte() {
    od -An -tx1 -N1 -j "$1" "$EC" 2>/dev/null | tr -d ' \n'
}

writebyte() {
    printf '%b' "$(printf '\\%03o' "$2")" | dd of="$EC" bs=1 seek="$1" count=1 conv=notrunc status=none
}

cleanup() {
    modprobe -r ec_sys >/dev/null 2>&1 || true
}
trap cleanup EXIT

# 9SE leaves bit 3 set while the killswitch is asserted. Always replay the
# double toggle when bit 3 is set; do not wait for rfkill, which can lag.
for attempt in 1 2 3; do
    if ! modprobe ec_sys write_support=1; then
        log "failed to load ec_sys (attempt $attempt)"
        sleep 2
        continue
    fi

    if [[ ! -e "$EC" ]]; then
        log "EC sysfs path missing: $EC"
        sleep 2
        continue
    fi

    hex=$(readbyte $((0x2e)))
    if [[ -z "$hex" ]]; then
        log "failed to read EC 0x2e"
        sleep 2
        continue
    fi

    val=$((0x$hex))
    log "$(printf 'attempt %s EC 0x2e=0x%02x hard_blocked=%s' "$attempt" "$val" "$(wifi_hard_blocked && echo yes || echo no)")"

    if (( (val & RADIO_BIT) == 0 )); then
        log "bit 3 already clear; leaving airplane mode alone"
        exit 0
    fi

    writebyte $((0x2e)) $((val & ~RADIO_BIT))
    sleep 1
    writebyte $((0x2e)) $((val | RADIO_BIT))
    modprobe -r ec_sys >/dev/null 2>&1 || true
    sleep 2

    if ! wifi_hard_blocked; then
        log "Wi-Fi unblocked"
        exit 0
    fi
    log "Wi-Fi still hard-blocked after attempt $attempt"
done

exit 0
