#!/bin/bash
LOG="/var/tmp/quickshell-main.log"
exec >> $LOG 2>&1

echo "--- Started at $(date) ---"
export QSG_RHI_BACKEND=vulkan # Prevents quickshell crash after sleep
quickshell
echo "--- Exited at $(date) ---"
