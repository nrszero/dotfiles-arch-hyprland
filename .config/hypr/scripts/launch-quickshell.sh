#!/bin/bash
LOG="/var/tmp/quickshell-main.log"
exec >> $LOG 2>&1

echo "--- Started at $(date) ---"
quickshell
echo "--- Exited at $(date) ---"
