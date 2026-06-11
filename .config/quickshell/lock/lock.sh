#!/bin/bash

LOG_FILE="/var/tmp/quickshell-lock.log"

# Function to log to both screen and file
log() {
    echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

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

LOCK_QML="$CONFIG_DIR/lock/shell.qml"
log "Lock QML file: $LOCK_QML"

if [ ! -f "$LOCK_QML" ]; then
    log "ERROR: Lock screen QML not found!"
    exit 1
fi

log "Killing any existing lock screen instances..."
pkill -f "quickshell.*lock/shell.qml" 2>/dev/null || log "No existing instances found."

log "Changing directory to $CONFIG_DIR"
cd "$CONFIG_DIR" || {
    log "ERROR: Failed to cd into $CONFIG_DIR"
    exit 1
}

log "Current working directory: $(pwd)"
log "Launching quickshell..."
log "Command: quickshell -p lock/shell.qml"

# Run quickshell and capture everything
quickshell -p lock/shell.qml >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
log "Quickshell exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    log "WARNING: Quickshell exited with non-zero code"
fi

log "Lock screen session ended."
