#!/bin/bash

STATE_FILE="$HOME/.config/hypr/last-headset-mac"

echo "→ Waiting for Bluetooth controller..."
timeout=15
while [ $timeout -gt 0 ]; do
    if bluetoothctl show | grep -q "Powered: yes"; then
        echo "→ Bluetooth ready"
        break
    fi
    sleep 0.5
    ((timeout--))
done

if [ $timeout -eq 0 ]; then
    echo "Bluetooth didn't become ready in time"
fi

# Try the last successfully connected headset first
if [ -f "$STATE_FILE" ]; then
    MAC=$(cat "$STATE_FILE" | tr -d ' \n')
    echo "→ Trying last known headset: $MAC"
    bluetoothctl disconnect "$MAC" 2>/dev/null
    sleep 1
    if bluetoothctl connect "$MAC"; then
        echo "Connected to last headset"
        exit 0
    fi
    echo "Last headset failed, falling back..."
fi

# Fallback: grab the last headset-like device in the paired list
MAC=$(bluetoothctl devices Paired | \
  grep -Ei 'headset|headphone|earbud|airpod|wh-|xm[0-9]|bose|sony|quietcomfort|ultra' | \
  tail -n 1 | awk '{print $2}')

if [ -n "$MAC" ]; then
    echo "→ Found headset in paired list: $MAC"
    echo "$MAC" > "$STATE_FILE"
    bluetoothctl disconnect "$MAC" 2>/dev/null
    sleep 1
    if bluetoothctl connect "$MAC"; then
        echo "Connected and saved as last headset"
    else
        echo "Connect failed"
    fi
else
    echo "No headset found"
fi
