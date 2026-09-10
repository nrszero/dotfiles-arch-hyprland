#!/bin/bash

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
LOG_FILE="$LOG_DIR/main.log"

if (umask 077; install -d -m 700 -- "$LOG_DIR" && touch -- "$LOG_FILE" && chmod 600 -- "$LOG_FILE"); then
    exec >> "$LOG_FILE" 2>&1 || printf '%s\n' "WARNING: Could not redirect Quickshell log; using inherited output." >&2
else
    printf '%s\n' "WARNING: Could not prepare Quickshell log; using inherited output." >&2
fi

echo "--- Started at $(date) ---"
export QSG_RHI_BACKEND=vulkan # Prevents quickshell crash after sleep
quickshell
echo "--- Exited at $(date) ---"
