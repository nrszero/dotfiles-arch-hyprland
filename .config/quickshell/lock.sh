#!/bin/bash

LOG_FILE="/var/tmp/quickshell-lock.log"
READY_FILE="/var/tmp/qs-lock-ready"

# Function to log to both screen and file
log() {
    echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

if [ "${1:-}" = "--wait-ready" ]; then
    i=0
    while [ "$i" -lt 80 ]; do
        if [ -s "$READY_FILE" ] && pgrep -f "quickshell.*lock-shell.qml" >/dev/null; then
            exit 0
        fi
        sleep 0.1
        i=$((i + 1))
    done
    log "WARNING: timed out waiting for lock screen to become ready"
    exit 0
fi

if [ "${1:-}" = "--after-sleep" ]; then
    hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' >/dev/null 2>&1 || true
    i=0
    while [ "$i" -lt 50 ]; do
        if hyprctl -j monitors 2>/dev/null | grep -q '"x": 0'; then
            break
        fi
        sleep 0.1
        i=$((i + 1))
    done
    date +%s > /var/tmp/qs-wake
    exit 0
fi

log "=========================================="
log "Starting Quickshell Lock Screen"
log "=========================================="

set -e

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

if [ -L "$CONFIG_DIR" ]; then
    REAL_CONFIG_DIR="$(readlink -f "$CONFIG_DIR")"
    log "Detected symlink. Real path: $REAL_CONFIG_DIR"
    CONFIG_DIR="$REAL_CONFIG_DIR"
else
    log "Using config dir: $CONFIG_DIR"
fi

LOCK_QML="$CONFIG_DIR/lock-shell.qml"
log "Lock QML file: $LOCK_QML"

if [ ! -f "$LOCK_QML" ]; then
    log "ERROR: Lock screen QML not found!"
    exit 1
fi
log "Checking for existing lock screen instances..."
if pgrep -f "quickshell.*lock-shell.qml" > /dev/null; then
    log "Lock screen is already running. Ignoring duplicate request."
    exit 0
fi

rm -f "$READY_FILE"

if command -v systemd-inhibit >/dev/null; then
    systemd-inhibit --what=sleep --who=qs-lock --why="Lock screen starting" --mode=delay \
        "$0" --wait-ready >/dev/null 2>&1 &
fi

log "Changing directory to $CONFIG_DIR"
cd "$CONFIG_DIR" || {
    log "ERROR: Failed to cd into $CONFIG_DIR"
    exit 1
}

log "Current working directory: $(pwd)"
log "Launching quickshell..."
log "Command: quickshell -p lock-shell.qml"

export QSG_RHI_BACKEND=vulkan # Prevent quickshell crash after sleep
export QSG_RENDER_LOOP=basic # Prevent DPMS deadlock

# Append so the startup lines above survive; do not truncate this file here.
quickshell -p lock-shell.qml >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
log "Quickshell exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    log "WARNING: Quickshell exited with non-zero code"
fi

rm -f "$READY_FILE"
log "Lock screen session ended."
