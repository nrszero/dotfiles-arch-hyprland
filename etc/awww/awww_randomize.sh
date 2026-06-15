#!/bin/bash
# Changes the wallpaper to a randomly chosen image in a given directory
# at a set interval.

DEFAULT_INTERVAL=600 # In seconds
CURRENT_USER=$(whoami)
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/tmp}" # resolves to /run/user/*
LOG_FILE="$RUNTIME_DIR/awww_wallpaper.log"
PID_FILE="$RUNTIME_DIR/awww_sleep.pid"
WALLPAPER_BASE="/usr/share/wallpapers"
STATE_FILE="/var/tmp/current_wallpaper_folder.txt"
DEFAULT_FOLDER="anime-scenery"

# Initialize log file
echo "--- Starting awww_randomize script for $CURRENT_USER ---" > "$LOG_FILE"

# --- 1. SHARED DYNAMIC DAEMON POLLING ---
# Both the greeter and the user must wait for the socket, so we do this first.
echo "[$(date '+%H:%M:%S')] [PID: $$] Polling for awww-daemon socket..." >> "$LOG_FILE"

TIMEOUT_LIMIT=50 # 50 retries * 0.1s = 5 seconds maximum wait
RETRY_COUNT=0

while ! awww query >/dev/null 2>&1; do
    if [ "$RETRY_COUNT" -ge "$TIMEOUT_LIMIT" ]; then
        echo "[$(date '+%H:%M:%S')] [PID: $$] FATAL: awww-daemon socket never opened." >> "$LOG_FILE"
        exit 1 
    fi
    sleep 0.1 
    RETRY_COUNT=$((RETRY_COUNT + 1))
done
echo "[$(date '+%H:%M:%S')] [PID: $$] awww-daemon is online and responding." >> "$LOG_FILE"
# ---------------------------------------- 

# --- 2. GREETER INTERCEPT ---
if [ "$CURRENT_USER" = "greeter" ]; then
    echo "--- Restoring persistent wallpaper for greeter ---" >> "$LOG_FILE"
    if [ -f "/var/tmp/greeter-wallpaper" ]; then
        awww clear 000000 >> "$LOG_FILE" 2>&1
        AWWW_OUTPUT=$(awww img --resize="crop" "/var/tmp/greeter-wallpaper" </dev/null 2>&1)
        
        if [ -z "$AWWW_OUTPUT" ]; then
            echo "[$(date '+%H:%M:%S')] [PID: $$] awww daemon response: (Command executed silently/successfully)" >> "$LOG_FILE"
        else
            echo "[$(date '+%H:%M:%S')] [PID: $$] awww daemon response: $AWWW_OUTPUT" >> "$LOG_FILE"
        fi
    else
        echo "[$(date '+%H:%M:%S')] [PID: $$] ERROR: /var/tmp/greeter-wallpaper does not exist!" >> "$LOG_FILE"
    fi
    exit 0
fi
# ----------------------------

# --- 3. OUTPUT STABILIZATION BUFFER ---
echo "[$(date '+%H:%M:%S')] [PID: $$] Dynamically polling for monitor initialization..." >> "$LOG_FILE"

# Ask the kernel how many displays are physically connected to the GPU
PHYSICAL_MONITORS=$(cat /sys/class/drm/card*-*/status 2>/dev/null | grep -c "^connected" || echo 1)

echo "[$(date '+%H:%M:%S')] [PID: $$] Hardware reports $PHYSICAL_MONITORS connected monitor(s)." >> "$LOG_FILE"

# Wait until Hyprland registers that exact number
while [ "$(hyprctl monitors all | grep -c 'Monitor')" -lt "$PHYSICAL_MONITORS" ]; do
    sleep 0.2
done

echo "[$(date '+%H:%M:%S')] [PID: $$] Hyprland monitor handshake complete." >> "$LOG_FILE"
# --------------------------------------

if [ $# -lt 1 ] || [ ! -d "$1" ]; then
	printf "Usage:\n\t\e[1m%s\e[0m \e[4mDIRECTORY\e[0m [\e[4mINTERVAL\e[0m]\n" "$0"
	printf "\tChanges the wallpaper to a randomly chosen image in DIRECTORY every\n\tINTERVAL seconds."
	exit 1
fi

# If hyprland autostart gave us the parent directory, load the last used subfolder instead
if [ "$1" = "$WALLPAPER_BASE" ]; then
    if [ -f "$STATE_FILE" ]; then
        read -r FOLDER_NAME < "$STATE_FILE"
        TARGET_DIR="$WALLPAPER_BASE/$FOLDER_NAME"
        echo "[$(date '+%H:%M:%S')] Using saved folder: $FOLDER_NAME" >> "$LOG_FILE"
    else
        # First run ever → pick first folder alphabetically
        FOLDER_NAME="$DEFAULT_FOLDER"
        TARGET_DIR="$WALLPAPER_BASE/$FOLDER_NAME"
        echo "[$(date '+%H:%M:%S')] No saved folder found, using default: $FOLDER_NAME" >> "$LOG_FILE"
    fi
else
    TARGET_DIR="$1"
fi

echo "$(basename "$TARGET_DIR")" > "$STATE_FILE" 2>/dev/null || true

RESIZE_TYPE="crop"
export AWWW_TRANSITION_FPS="${AWWW_TRANSITION_FPS:-60}"
export AWWW_TRANSITION_STEP="${AWWW_TRANSITION_STEP:-2}"

while true; do
	mapfile -t images < <(find -L "$TARGET_DIR" -type f | shuf)

	for img in "${images[@]}"; do
		IS_FULLSCREEN=$(hyprctl clients | grep 'fullscreen: 2')
		if [ -n "$IS_FULLSCREEN" ]; then
            sleep 5 </dev/null &
			SLEEP_PID=$!
			echo "$SLEEP_PID" > "$PID_FILE"
			wait $SLEEP_PID
		else
			# Atomic Image Backup
			cp "$img" "/var/tmp/greeter-wallpaper.tmp"
			chmod 644 "/var/tmp/greeter-wallpaper.tmp"
			mv "/var/tmp/greeter-wallpaper.tmp" "/var/tmp/greeter-wallpaper"

			# 1. Set the wallpaper and extract colors
			awww img --resize="$RESIZE_TYPE" "$img" </dev/null
			wal -i "$img" -n -q -s
			if [ -f "$HOME/.cache/wal/colors.sh" ]; then
			    source "$HOME/.cache/wal/colors.sh"
			else
			    echo "[$(date '+%H:%M:%S')] ERROR: Pywal colors.sh not found!" >> "$LOG_FILE"
			fi
			
			# 2. Generate Hyprland colors
			cat << EOF > "$HOME/.cache/wal/colors.lua"
return {
    color0 = "${color0}",
    color10 = "${color10}",
    color12 = "${color12}"
}
EOF
			# 3. Generate Rofi colors
			cat << EOF > "$HOME/.cache/wal/colors-rounded-glass.rasi"
* {
    bg0:    ${color0}33;
    bg1:    ${color10}cc;
    bg2:    ${color0}33;
    bg3:    ${color0}33;
    bg4:    ${color0}33;
    fg0:    ${color15}cc;
    fg1:    ${color15}cc;
    fg2:    ${color15}cc;
    fg3:    ${color15}cc;
}
EOF
			# 4. Atomic JSON Backup
			cp "$HOME/.cache/wal/colors.json" "/var/tmp/greeter-colors.tmp"
			chmod 644 "/var/tmp/greeter-colors.tmp"
			mv "/var/tmp/greeter-colors.tmp" "/var/tmp/greeter-colors.json"

			echo "[$(date '+%H:%M:%S')] DEBUG: Reloading Hyprland..." >> "$LOG_FILE"
			hyprctl reload >> "$LOG_FILE" 2>&1
		
			# 5. Sleep cycle
			SLEEP_TIME="${2:-$DEFAULT_INTERVAL}"
			echo "[$(date '+%H:%M:%S')] Set wallpaper: $(basename "$img")" >> "$LOG_FILE"
			
			sleep "$SLEEP_TIME" </dev/null &
			SLEEP_PID=$!
			
			echo "$SLEEP_PID" > "$PID_FILE"
			echo "[$(date '+%H:%M:%S')] Started sleep (PID: $SLEEP_PID) for $SLEEP_TIME seconds." >> "$LOG_FILE"
			
			wait $SLEEP_PID
			WAIT_STATUS=$?
			
			if [ $WAIT_STATUS -gt 128 ]; then
				echo "[$(date '+%H:%M:%S')] -> INTERRUPTED: Sleep killed (Next wallpaper triggered)." >> "$LOG_FILE"
			else
				echo "[$(date '+%H:%M:%S')] -> NATURAL: Sleep finished." >> "$LOG_FILE"
			fi
			echo "-----------------------------------" >> "$LOG_FILE"
		fi
	done

	sleep 1
done
