#!/bin/bash
# Cycles to the next wallpaper folder in /usr/share/wallpapers

WALLPAPER_BASE="/usr/share/wallpapers"
STATE_FILE="/tmp/current_wallpaper_folder.txt"

# Get sorted list of subfolder names
mapfile -t folders < <(find -L "$WALLPAPER_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

if [ ${#folders[@]} -eq 0 ]; then
  notify-send "Wallpaper Error" "No subfolders found in $WALLPAPER_BASE" 2>/dev/null || echo "No wallpaper folders found!"
  exit 1
fi

# Read current folder (or default to the first one)
if [ -f "$STATE_FILE" ]; then
  CURRENT=$(cat "$STATE_FILE" | tr -d '\n')
else
  CURRENT="${folders[0]}"
fi

# Find current index
CURRENT_INDEX=-1
for i in "${!folders[@]}"; do
  if [ "${folders[$i]}" = "$CURRENT" ]; then
    CURRENT_INDEX=$i
    break
  fi
done

if [ $CURRENT_INDEX -eq -1 ]; then
  CURRENT_INDEX=0
fi

# Next folder (wraps around)
NEXT_INDEX=$(( (CURRENT_INDEX + 1) % ${#folders[@]} ))
NEXT_FOLDER="${folders[$NEXT_INDEX]}"
NEXT_PATH="$WALLPAPER_BASE/$NEXT_FOLDER"

# Save new state
echo "$NEXT_FOLDER" > "$STATE_FILE"

# Kill the old randomize script (and its sleep)
pkill -f "awww_randomize.sh" 2>/dev/null || true
sleep 0.3

# Start the randomize script with the new folder
nohup /etc/awww/awww_randomize.sh "$NEXT_PATH" >/dev/null 2>&1 &

# Nice notification
notify-send "Wallpaper Folder Changed" "Now using: $NEXT_FOLDER" -t 4000 2>/dev/null || \
  echo "Switched to wallpaper folder: $NEXT_FOLDER"

echo "Switched to: $NEXT_FOLDER"
