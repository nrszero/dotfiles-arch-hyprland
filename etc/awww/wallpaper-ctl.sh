#!/bin/bash
# Wallpaper controller: apply, rotate, and persist settings for awww + pywal.

CURRENT_USER=$(whoami)
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/tmp}"
LOG_FILE="$RUNTIME_DIR/awww_wallpaper.log"
PID_FILE="$RUNTIME_DIR/awww_sleep.pid"
DAEMON_PID_FILE="$RUNTIME_DIR/awww_daemon.pid"
WALLPAPER_BASE="/usr/share/wallpapers"
LEGACY_STATE="/var/tmp/current_wallpaper_folder.txt"
STATE_DIR="${HOME:-/tmp}/.config/awww"
STATE_FILE="$STATE_DIR/state.json"
DEFAULT_FOLDER="anime-scenery"
DEFAULT_INTERVAL=600
BLUR_RADIUS="0x8"
LOCK_WALL_TMP="/var/tmp/greeter-wallpaper.tmp"
RESIZE_TYPE="crop"
SELF="$(readlink -f "$0" 2>/dev/null || echo "$0")"

export AWWW_TRANSITION_FPS="${AWWW_TRANSITION_FPS:-60}"
export AWWW_TRANSITION_STEP="${AWWW_TRANSITION_STEP:-2}"

log() {
	echo "[$(date '+%H:%M:%S')] [PID: $$] $*" >> "$LOG_FILE"
}

wait_for_awww() {
	local timeout_limit=50 retry_count=0
	log "Polling for awww-daemon socket..."
	while ! awww query >/dev/null 2>&1; do
		if [ "$retry_count" -ge "$timeout_limit" ]; then
			log "FATAL: awww-daemon socket never opened."
			exit 1
		fi
		sleep 0.1
		retry_count=$((retry_count + 1))
	done
	log "awww-daemon is online and responding."
}

greeter_restore() {
	log "--- Restoring persistent wallpaper for greeter ---"
	if [ -f "/var/tmp/greeter-wallpaper" ]; then
		awww clear 000000 >> "$LOG_FILE" 2>&1
		AWWW_OUTPUT=$(awww img --resize="crop" "/var/tmp/greeter-wallpaper" </dev/null 2>&1)
		if [ -z "$AWWW_OUTPUT" ]; then
			log "awww daemon response: (Command executed silently/successfully)"
		else
			log "awww daemon response: $AWWW_OUTPUT"
		fi
	else
		log "ERROR: /var/tmp/greeter-wallpaper does not exist!"
	fi
}

wait_for_monitors() {
	log "Dynamically polling for monitor initialization..."
	PHYSICAL_MONITORS=$(cat /sys/class/drm/card*-*/status 2>/dev/null | grep -c "^connected" || echo 1)
	log "Hardware reports $PHYSICAL_MONITORS connected monitor(s)."
	while [ "$(hyprctl monitors all | grep -c 'Monitor')" -lt "$PHYSICAL_MONITORS" ]; do
		sleep 0.2
	done
	log "Hyprland monitor handshake complete."
}

py_state() {
	python3 - "$STATE_FILE" "$WALLPAPER_BASE" "$LEGACY_STATE" "$DEFAULT_FOLDER" "$DEFAULT_INTERVAL" "$@" <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

state_path = Path(sys.argv[1])
base = Path(sys.argv[2])
legacy_path = Path(sys.argv[3])
default_folder = sys.argv[4]
default_interval = int(sys.argv[5])
action = sys.argv[6]
args = sys.argv[7:]

EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff"}


def find_folders():
    if not base.is_dir():
        return []
    try:
        out = subprocess.check_output(
            ["find", "-L", str(base), "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-printf", "%f\n"],
            text=True,
        )
    except subprocess.CalledProcessError:
        return []
    return sorted(line for line in out.splitlines() if line)


def find_images(folder):
    target = base / folder
    if not folder or not target.exists():
        return []
    try:
        out = subprocess.check_output(
            [
                "find", "-L", str(target), "-type", "f",
                "(",
                "-iname", "*.jpg", "-o",
                "-iname", "*.jpeg", "-o",
                "-iname", "*.png", "-o",
                "-iname", "*.webp", "-o",
                "-iname", "*.gif", "-o",
                "-iname", "*.bmp", "-o",
                "-iname", "*.tif", "-o",
                "-iname", "*.tiff",
                ")",
            ],
            text=True,
        )
    except subprocess.CalledProcessError:
        return []
    return sorted(line for line in out.splitlines() if line)


def defaults():
    folder = default_folder
    if not state_path.exists() and legacy_path.is_file():
        legacy = legacy_path.read_text(encoding="utf-8", errors="replace").strip()
        if legacy:
            folder = legacy
    folders = find_folders()
    if folder not in folders and folders:
        folder = folders[0] if default_folder not in folders else default_folder
    return {
        "auto": True,
        "shuffle": True,
        "folder": folder,
        "wallpaper": "",
        "interval": default_interval,
    }


def load():
    data = defaults()
    if state_path.exists():
        try:
            loaded = json.loads(state_path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                data.update(loaded)
        except (json.JSONDecodeError, OSError):
            pass
    data["auto"] = bool(data.get("auto", True))
    data["shuffle"] = bool(data.get("shuffle", True))
    try:
        data["interval"] = int(data.get("interval", default_interval))
    except (TypeError, ValueError):
        data["interval"] = default_interval
    if data["interval"] < 1:
        data["interval"] = default_interval
    data["folder"] = str(data.get("folder") or default_folder)
    data["wallpaper"] = str(data.get("wallpaper") or "")
    return data


def save(data):
    state_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = state_path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    tmp.replace(state_path)


def pick(images, current, shuffle):
    if not images:
        return ""
    if current in images:
        if len(images) == 1:
            return current
        if shuffle:
            choices = [p for p in images if p != current]
            return choices[int.from_bytes(os.urandom(2), "little") % len(choices)]
        return images[(images.index(current) + 1) % len(images)]
    if shuffle:
        return images[int.from_bytes(os.urandom(2), "little") % len(images)]
    return images[0]


data = load()

if action == "ensure":
    if not state_path.exists():
        save(data)
    sys.exit(0)

if action == "get":
    key = args[0]
    val = data.get(key, "")
    if isinstance(val, bool):
        print("1" if val else "0")
    else:
        print(val)
    sys.exit(0)

if action == "patch":
    patch = json.loads(args[0])
    data.update(patch)
    data["auto"] = bool(data.get("auto", True))
    data["shuffle"] = bool(data.get("shuffle", True))
    try:
        data["interval"] = int(data.get("interval", default_interval))
    except (TypeError, ValueError):
        data["interval"] = default_interval
    data["folder"] = str(data.get("folder") or default_folder)
    data["wallpaper"] = str(data.get("wallpaper") or "")
    save(data)
    sys.exit(0)

if action == "pick":
    mode = args[0]  # next | folder
    folder = args[1] if len(args) > 1 else data["folder"]
    images = find_images(folder)
    if mode == "folder":
        print(pick(images, "", bool(data["shuffle"])))
    else:
        print(pick(images, data.get("wallpaper", ""), bool(data["shuffle"])))
    sys.exit(0)

if action == "status":
    folder = data.get("folder", "")
    payload = {
        "auto": bool(data.get("auto", True)),
        "shuffle": bool(data.get("shuffle", True)),
        "folder": folder,
        "wallpaper": data.get("wallpaper", ""),
        "interval": int(data.get("interval", default_interval)),
        "folders": find_folders(),
        "images": find_images(folder),
    }
    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0)

print(f"unknown python action: {action}", file=sys.stderr)
sys.exit(2)
PY
}

ensure_state() {
	mkdir -p "$STATE_DIR"
	py_state ensure
}

state_get() {
	py_state get "$1"
}

state_patch() {
	py_state patch "$1"
}

pick_image() {
	py_state pick "$1" "$2"
}

is_fullscreen() {
	hyprctl clients 2>/dev/null | grep -q 'fullscreen: 2'
}

apply_wallpaper() {
	local img="$1"
	if [ -z "$img" ] || [ ! -f "$img" ]; then
		log "ERROR: wallpaper file missing: $img"
		return 1
	fi

	awww img --resize="$RESIZE_TYPE" "$img" </dev/null
	wal -i "$img" -n -q -s
	if [ -f "$HOME/.cache/wal/colors.sh" ]; then
		# shellcheck disable=SC1091
		source "$HOME/.cache/wal/colors.sh"
	else
		log "ERROR: Pywal colors.sh not found!"
	fi

	cat << EOF > "$HOME/.cache/wal/colors.lua"
return {
    color0 = "${color0}",
    color2 = "${color2}",
    color6 = "${color6}",
    color8 = "${color8}",
    color9 = "${color9}",
    color10 = "${color10}",
    color12 = "${color12}"
}
EOF
	if [ -f "$HOME/.cache/wal/colors.json" ]; then
		cp "$HOME/.cache/wal/colors.json" "/var/tmp/greeter-colors.tmp"
		chmod 644 "/var/tmp/greeter-colors.tmp"
		mv "/var/tmp/greeter-colors.tmp" "/var/tmp/greeter-colors.json"
	fi

	log "Reloading Hyprland..."
	hyprctl reload >> "$LOG_FILE" 2>&1

	convert "$img" \
		-resize 2560x1440^ \
		-gravity center \
		-extent 2560x1440 \
		-blur "$BLUR_RADIUS" \
		-quality 85 \
		"$LOCK_WALL_TMP"
	chmod 644 "$LOCK_WALL_TMP"
	mv "$LOCK_WALL_TMP" "/var/tmp/greeter-wallpaper"
	log "Set wallpaper: $(basename "$img") (blur=$BLUR_RADIUS)"
}

folder_from_wallpaper() {
	local img="$1"
	case "$img" in
		"$WALLPAPER_BASE"/*)
			local rest="${img#"$WALLPAPER_BASE"/}"
			echo "${rest%%/*}"
			;;
		*)
			state_get folder
			;;
	esac
}

json_escape() {
	python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

signal_daemon() {
	if [ -f "$PID_FILE" ]; then
		kill "$(cat "$PID_FILE")" 2>/dev/null || true
	fi
}

daemon_running() {
	local pid=""
	[ -f "$DAEMON_PID_FILE" ] || return 1
	pid=$(cat "$DAEMON_PID_FILE" 2>/dev/null || true)
	[ -n "$pid" ] && [ "$pid" != "$$" ] && kill -0 "$pid" 2>/dev/null
}

ensure_daemon() {
	if daemon_running; then
		signal_daemon
		return
	fi
	nohup "$SELF" daemon >/dev/null 2>&1 &
}

sleep_interruptible() {
	local seconds="$1"
	sleep "$seconds" </dev/null &
	local sleep_pid=$!
	echo "$sleep_pid" > "$PID_FILE"
	log "Started sleep (PID: $sleep_pid) for $seconds seconds."
	wait "$sleep_pid"
	local status=$?
	rm -f "$PID_FILE"
	return $status
}

resolve_current() {
	local folder img
	folder=$(state_get folder)
	img=$(state_get wallpaper)
	if [ -n "$img" ] && [ -f "$img" ]; then
		echo "$img"
		return
	fi
	img=$(pick_image folder "$folder")
	if [ -n "$img" ]; then
		state_patch "{\"wallpaper\": $(json_escape "$img")}"
	fi
	echo "$img"
}

cmd_status() {
	ensure_state
	py_state status
}

cmd_next() {
	ensure_state
	local folder next
	folder=$(state_get folder)
	next=$(pick_image next "$folder")
	if [ -z "$next" ]; then
		log "ERROR: no images in folder $folder"
		return 1
	fi
	state_patch "{\"wallpaper\": $(json_escape "$next")}"
	apply_wallpaper "$next"
	ensure_daemon
}

cmd_next_folder() {
	ensure_state
	local next_folder next
	next_folder=$(python3 - "$WALLPAPER_BASE" "$(state_get folder)" <<'PY'
import subprocess, sys
base, current = sys.argv[1], sys.argv[2]
try:
    out = subprocess.check_output(
        ["find", "-L", base, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-printf", "%f\n"],
        text=True,
    )
except subprocess.CalledProcessError:
    sys.exit(1)
folders = sorted(line for line in out.splitlines() if line)
if not folders:
    sys.exit(1)
if current in folders:
    nxt = folders[(folders.index(current) + 1) % len(folders)]
else:
    nxt = folders[0]
print(nxt)
PY
	)
	if [ -z "$next_folder" ]; then
		log "ERROR: no wallpaper folders found"
		return 1
	fi
	next=$(pick_image folder "$next_folder")
	if [ -z "$next" ]; then
		state_patch "{\"folder\": $(json_escape "$next_folder")}"
		log "Switched to empty folder: $next_folder"
		ensure_daemon
		return 1
	fi
	state_patch "{\"folder\": $(json_escape "$next_folder"), \"wallpaper\": $(json_escape "$next")}"
	apply_wallpaper "$next"
	ensure_daemon
}

parse_bool() {
	case "${1,,}" in
		1|true|on|yes) echo true ;;
		0|false|off|no) echo false ;;
		*) return 1 ;;
	esac
}

cmd_set() {
	local key="${1:-}" value="${2:-}"
	if [ -z "$key" ]; then
		echo "Usage: $0 set auto|shuffle|folder|wallpaper|interval VALUE" >&2
		return 1
	fi
	ensure_state
	case "$key" in
		auto|shuffle)
			local bool
			bool=$(parse_bool "$value") || {
				echo "Invalid boolean: $value" >&2
				return 1
			}
			state_patch "{\"${key}\": ${bool}}"
			ensure_daemon
			;;
		interval)
			if ! [ "$value" -ge 1 ] 2>/dev/null; then
				echo "Invalid interval: $value" >&2
				return 1
			fi
			state_patch "{\"interval\": ${value}}"
			ensure_daemon
			;;
		folder)
			local name="$value"
			if [ -d "$value" ]; then
				name=$(basename "$value")
			fi
			if [ ! -d "$WALLPAPER_BASE/$name" ]; then
				echo "Unknown folder: $name" >&2
				return 1
			fi
			if [ "$(state_get auto)" = "1" ]; then
				local next
				next=$(pick_image folder "$name")
				if [ -n "$next" ]; then
					state_patch "{\"folder\": $(json_escape "$name"), \"wallpaper\": $(json_escape "$next")}"
					apply_wallpaper "$next"
				else
					state_patch "{\"folder\": $(json_escape "$name")}"
				fi
			else
				state_patch "{\"folder\": $(json_escape "$name")}"
			fi
			ensure_daemon
			;;
		wallpaper)
			if [ ! -f "$value" ]; then
				echo "Wallpaper not found: $value" >&2
				return 1
			fi
			local folder
			folder=$(folder_from_wallpaper "$value")
			state_patch "{\"auto\": false, \"wallpaper\": $(json_escape "$value"), \"folder\": $(json_escape "$folder")}"
			apply_wallpaper "$value"
			ensure_daemon
			;;
		*)
			echo "Unknown setting: $key" >&2
			return 1
			;;
	esac
}

kill_other_daemons() {
	local pid=""
	if [ -f "$DAEMON_PID_FILE" ]; then
		pid=$(cat "$DAEMON_PID_FILE" 2>/dev/null || true)
		if [ -n "$pid" ] && [ "$pid" != "$$" ]; then
			kill "$pid" 2>/dev/null || true
		fi
	fi
	if [ -f "$PID_FILE" ]; then
		kill "$(cat "$PID_FILE")" 2>/dev/null || true
	fi
	pkill -f "/etc/awww/awww_randomize.sh" 2>/dev/null || true
}

cmd_daemon() {
	echo "--- Starting wallpaper-ctl daemon for $CURRENT_USER ---" > "$LOG_FILE"
	wait_for_awww
	wait_for_monitors
	kill_other_daemons
	echo $$ > "$DAEMON_PID_FILE"
	ensure_state

	local img
	img=$(resolve_current)
	if [ -n "$img" ]; then
		apply_wallpaper "$img"
	else
		log "ERROR: no wallpaper to apply"
	fi

	while true; do
		local auto interval status
		auto=$(state_get auto)
		interval=$(state_get interval)
		if [ "$auto" = "1" ]; then
			sleep_interruptible "$interval"
			status=$?
		else
			sleep_interruptible infinity
			status=$?
		fi

		if [ "$status" -gt 128 ]; then
			log "INTERRUPTED: sleep killed (settings changed or next triggered)."
			continue
		fi

		auto=$(state_get auto)
		if [ "$auto" != "1" ]; then
			continue
		fi
		if is_fullscreen; then
			log "Fullscreen client present; delaying auto-advance."
			sleep_interruptible 5 || true
			continue
		fi

		local folder next
		folder=$(state_get folder)
		next=$(pick_image next "$folder")
		if [ -z "$next" ]; then
			log "ERROR: no images in folder $folder"
			sleep_interruptible 5 || true
			continue
		fi
		state_patch "{\"wallpaper\": $(json_escape "$next")}"
		apply_wallpaper "$next"
	done
}

usage() {
	printf "Usage:\n"
	printf "  %s daemon\n" "$0"
	printf "  %s next\n" "$0"
	printf "  %s next-folder\n" "$0"
	printf "  %s set auto|shuffle|folder|wallpaper|interval VALUE\n" "$0"
	printf "  %s status\n" "$0"
}

if [ "$CURRENT_USER" = "greeter" ]; then
	echo "--- Starting wallpaper-ctl for greeter ---" > "$LOG_FILE"
	wait_for_awww
	greeter_restore
	exit 0
fi

cmd="${1:-daemon}"
if [ $# -gt 0 ]; then
	shift
fi

case "$cmd" in
	daemon)
		cmd_daemon
		;;
	next)
		cmd_next
		;;
	next-folder)
		cmd_next_folder
		;;
	set)
		cmd_set "$@"
		;;
	status)
		cmd_status
		;;
	-h|--help|help)
		usage
		;;
	*)
		# Ignore leftover directory args from the old randomize script.
		if [ -d "$cmd" ]; then
			cmd_daemon
		else
			usage >&2
			exit 1
		fi
		;;
esac
