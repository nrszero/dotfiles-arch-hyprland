#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER=""

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
sub_log() { printf '\033[1;34m  ->\033[0m %s\n' "$*"; } # Use this inside functions
warn() { printf '\033[1;33m==> WARNING:\033[0m %s\n' "$*"; }
success() { printf '\033[1;32m==> SUCCESS:\033[0m %s\n' "$*"; }

prompt_menu() {
    if [[ "${SKIP_PACKAGES:-0}" == "1" ]]; then
        return
    fi

    echo ""
    log "Please select a package installation option:"
    echo "  1) Install required packages"
    echo "  2) Install full packages"
    echo "  3) Install no packages"
    echo ""
    read -r -p "Enter choice [1-3]: " choice
    
    case $choice in
        1) INSTALL_MODE="required" ;;
        2) INSTALL_MODE="full" ;;
        3) INSTALL_MODE="none" ;;
        *) warn "Invalid option. Exiting."; exit 1 ;;
    esac
}

get_packages() {
    local section=$1
    awk -v sec="[$section]" '
        $0 == sec {flag=1; next}     # Start capturing when header matches
        /^\[.*\]$/ {flag=0}          # Stop capturing at the next header
        flag && NF {print $1}        # Print non-empty lines
    ' "$DOTFILES/install/requirements.txt"
}

append_kernel_params() {
    local cmdline=$1
    shift

    local param
    for param in "$@"; do
        [[ " $cmdline " == *" $param "* ]] ||
            cmdline="${cmdline:+$cmdline }$param"
    done

    printf '%s' "$cmdline"
}

configure_grub_kernel_params() {
    local defaults_file="/etc/default/grub"
    local current new_cmdline replacement

    if [[ $(grep -c '^GRUB_CMDLINE_LINUX_DEFAULT=' "$defaults_file") -ne 1 ]]; then
        warn "GRUB_CMDLINE_LINUX_DEFAULT is missing or duplicated; leaving GRUB untouched."
        return
    fi

    current="$(sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/\1/p' "$defaults_file")"
    new_cmdline="$(append_kernel_params "$current" "$@")"
    if [[ "$new_cmdline" == "$current" ]]; then
        sub_log "GRUB already contains the required NVIDIA kernel parameters."
        return
    fi

    replacement="${new_cmdline//\\/\\\\}"
    replacement="${replacement//&/\\&}"
    replacement="${replacement//|/\\|}"
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*$|GRUB_CMDLINE_LINUX_DEFAULT=\"$replacement\"|" "$defaults_file"

    sub_log "Regenerating GRUB configuration..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}

configure_uki_kernel_params() {
    local cmdline_file="/etc/kernel/cmdline"
    local current new_cmdline

    current="$(< "$cmdline_file")"
    new_cmdline="$(append_kernel_params "$current" "$@")"
    if [[ "$new_cmdline" == "$current" ]]; then
        sub_log "UKI command line already contains the required NVIDIA kernel parameters."
        return
    fi

    printf '%s\n' "$new_cmdline" | sudo tee "$cmdline_file" >/dev/null

    sub_log "Regenerating unified kernel images..."
    sudo mkinitcpio -P
}

configure_nvidia_kernel_params() {
    local backend_found=0
    local -a params=(
        "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        "nvidia_drm.modeset=1"
    )

    if [[ -f /etc/default/grub && -f /boot/grub/grub.cfg ]] \
            && command -v grub-mkconfig >/dev/null 2>&1; then
        backend_found=1
        sub_log "Updating NVIDIA kernel parameters for GRUB."
        configure_grub_kernel_params "${params[@]}"
    fi

    if [[ -f /etc/kernel/cmdline ]] \
            && command -v mkinitcpio >/dev/null 2>&1 \
            && grep -qsE '^[[:space:]]*[[:alnum:]_]+_uki=' /etc/mkinitcpio.d/*.preset; then
        backend_found=1
        sub_log "Updating NVIDIA kernel parameters for UKI."
        configure_uki_kernel_params "${params[@]}"
    fi

    if (( ! backend_found )); then
        warn "No usable GRUB or mkinitcpio UKI backend was detected; leaving boot configuration untouched."
    fi
}

check_dependencies() {
    log "Checking prerequisites..."
    local deps=("git" "stow")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            warn "'$dep' is not installed. Please install it before running this script."
            exit 1
        fi
    done
}

check_installer() {
    log "Checking for installer..."
    if command -v "yay" >/dev/null 2>&1; then
        INSTALLER="yay"
        sub_log "Installer yay found!"
    elif command -v "paru" >/dev/null 2>&1; then
        INSTALLER="paru"
        sub_log "Installer paru found!"
    else
        warn "Installer yay or paru not found. Please install one before running this script."
        exit 1
    fi
}

enable_multilib() {
    log "Checking multilib repository status..."
    
    # Check if [multilib] is already uncommented
    if grep -q "^\[multilib\]" /etc/pacman.conf; then
        sub_log "multilib is already enabled."
    else
        sub_log "Enabling multilib in /etc/pacman.conf..."
        
        # sed logic: find ^#[multilib], remove the #, move to next line (n), remove the #
        sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//;}' /etc/pacman.conf
        
        sub_log "Syncing pacman databases..."
        sudo pacman -Sy
    fi
}

install_packages() {
    if [[ "${SKIP_PACKAGES:-0}" == "1" ]] || [[ "$INSTALL_MODE" == "none" ]]; then
        log "Skipping package installation."
        return
    fi
    
    log "Parsing packages from install/requirements.txt..."
    
    # Read packages into an array safely
    mapfile -t req_pkgs < <(get_packages "required")
    
    if [[ "$INSTALL_MODE" == "full" ]]; then
        mapfile -t full_pkgs < <(get_packages "full")
        req_pkgs+=("${full_pkgs[@]}")
    fi

    # Pass the array to yay or paru
    "$INSTALLER" -S --needed --noconfirm "${req_pkgs[@]}"

    config_system

    success "All packages installed and system configured."
}

config_system() {
    if ! command -v lspci >/dev/null 2>&1; then
        warn "lspci is unavailable; install pciutils before configuring GPU drivers."
        return 1
    fi

    local -a gpu_vendors=()
    local -a gpu_pkgs=()
    local -a nvidia_device_ids=()
    local vendor package_section vendor_name device
    local nvidia_id_file="$DOTFILES/install/data/nvidia-open-gpu-ids.txt"
    local nvidia_detected=0
    local nvidia_manual=0

    mapfile -t gpu_vendors < <(
        LC_ALL=C lspci -Dn |
            awk '$2 ~ /^03/ { split($3, id, ":"); print tolower(id[1]) }' |
            LC_ALL=C sort -u
    )

    if (( ${#gpu_vendors[@]} == 0 )); then
        warn "No PCI display controller was detected; skipping GPU-specific Vulkan drivers."
    fi

    for vendor in "${gpu_vendors[@]}"; do
        if [[ "$vendor" == "10de" ]]; then
            nvidia_detected=1
            break
        fi
    done

    if (( nvidia_detected )); then
        if [[ ! -r "$nvidia_id_file" ]]; then
            warn "The NVIDIA open-module compatibility list is missing: $nvidia_id_file"
            nvidia_manual=1
        else
            mapfile -t nvidia_device_ids < <(
                LC_ALL=C lspci -Dn |
                    awk '$2 ~ /^03/ {
                        split(tolower($3), id, ":")
                        if (id[1] == "10de") print id[2]
                    }' |
                    LC_ALL=C sort -u
            )

            if (( ${#nvidia_device_ids[@]} == 0 )); then
                warn "NVIDIA was detected, but its display-controller device ID could not be read."
                nvidia_manual=1
            fi

            for device in "${nvidia_device_ids[@]}"; do
                if grep -Fxq -- "$device" "$nvidia_id_file"; then
                    sub_log "NVIDIA GPU 10de:$device supports the open kernel modules."
                else
                    warn "NVIDIA GPU 10de:$device is not in the reviewed open-module compatibility list."
                    nvidia_manual=1
                fi
            done
        fi

        if (( nvidia_manual )); then
            warn "Automatic NVIDIA setup stopped; no NVIDIA packages, services, or boot settings were changed."
            warn "Select the appropriate proprietary or legacy driver manually for the reported PCI ID."
            return 1
        fi
    fi

    for vendor in "${gpu_vendors[@]}"; do
        case "$vendor" in
            8086)
                vendor_name="Intel"
                package_section="intel"
                ;;
            1002)
                vendor_name="AMD"
                package_section="amd"
                ;;
            10de)
                vendor_name="NVIDIA"
                package_section="nvidia-open"
                ;;
            *)
                warn "Unsupported display-controller vendor ID $vendor; skipping its Vulkan drivers."
                continue
                ;;
        esac

        sub_log "$vendor_name GPU detected (vendor ID $vendor). Installing its driver packages..."
        mapfile -t gpu_pkgs < <(get_packages "$package_section")
        "$INSTALLER" -S --needed --noconfirm "${gpu_pkgs[@]}"
    done

    if (( nvidia_detected )); then

        sub_log "Enabling Wayland sleep services..."
        sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

        configure_nvidia_kernel_params
    else
        sub_log "No NVIDIA GPU detected. Skipping NVIDIA sleep hooks."
    fi
    
    # Bluetooth hardware detection
    sub_log "Checking for Bluetooth hardware..."
    if { command -v rfkill >/dev/null 2>&1 && rfkill list bluetooth | grep -iq "bluetooth"; } || \
       { command -v lspci >/dev/null 2>&1 && lspci | grep -iq "bluetooth"; } || \
       { command -v lsusb >/dev/null 2>&1 && lsusb | grep -iq "bluetooth"; }; then
        sub_log "Bluetooth adapter detected. Enabling bluetooth.service..."
        sudo systemctl enable bluetooth.service
    else
        sub_log "No Bluetooth adapter detected. Skipping bluetooth.service."
    fi

    # Enable required services
    sub_log "Enabling greetd service..."
    sudo systemctl enable greetd.service
}

copy_etc() {
    if [ ! -d "$DOTFILES/etc" ]; then
        log "No etc/ directory found in dotfiles. Skipping system config copy."
        return
    fi

    log "Copying system configuration from dotfiles/etc/ to /etc/..."
    
    # Copy files while forcing root ownership
    sudo rsync -a --backup --suffix=.bak \
        --exclude='.git' \
        --exclude='.stow-local-ignore' \
        --chown=root:root \
        "$DOTFILES/etc/" /etc/

    # Enforce correct permissions after copy
    sudo find /etc/greetd /etc/pam.d /etc/awww -type f ! -name "*.sh" -exec chmod 644 {} + 2>/dev/null || true
    sudo find /etc/greetd /etc/pam.d /etc/awww -type f -name "*.sh" -exec chmod 755 {} + 2>/dev/null || true
    sudo find /etc/greetd /etc/pam.d /etc/awww -type d -exec chmod 755 {} + 2>/dev/null || true

    success "System configuration copied with correct root ownership and permissions."
}

stow_user() {
    log "Checking for existing user configs to backup..."
    local config_target="$HOME/.config"
    local backup_dir="$HOME/.config.bak/$(date +%Y%m%d_%H%M%S)"
    local made_backup=0

    # Ensure the repo has a .config directory before trying to read it
    if [ -d "$DOTFILES/.config" ]; then
        # Enable dotglob to include hidden files/folders in the loop, nullglob to prevent literal '*' if empty
        shopt -s dotglob nullglob
        
        for item in "$DOTFILES/.config"/*; do
            local base_item=$(basename "$item")
            local target_item="$config_target/$base_item"

            # If the target path exists on the local machine and is NOT already a symlink
            if [ -e "$target_item" ] && [ ! -L "$target_item" ]; then
                # Create the backup directory only if we actually find a conflict
                if [ $made_backup -eq 0 ]; then
                    mkdir -p "$backup_dir"
                    sub_log "Created backup directory: $backup_dir"
                    made_backup=1
                fi
                
                sub_log "Moving existing config to backup: $base_item"
                mv "$target_item" "$backup_dir/"
            fi
        done
        
        # Reset shell options to default
        shopt -u dotglob nullglob
    fi

    log "Stowing user configs (.config/)..."
    stow -v --target "$config_target" --restow .config
   
    # Backup default .bashrc if it exists and isn't a symlink
    local bashrc_target="$HOME/.bashrc"
    if [ -f "$bashrc_target" ] && [ ! -L "$bashrc_target" ]; then
        if [ $made_backup -eq 0 ]; then
            mkdir -p "$backup_dir"
            sub_log "Created backup directory: $backup_dir"
            made_backup=1
        fi
        
        sub_log "Moving existing .bashrc to backup"
        mv "$bashrc_target" "$backup_dir/"
    fi

    log "Stowing (.bashrc)..."
    stow -v --target "$HOME" --restow home
}

stow_wallpapers() {
    log "Stowing wallpapers to /usr/share/wallpapers..."
    if [ -d "$DOTFILES/wallpapers" ]; then
        sudo mkdir -p /usr/share/wallpapers
        sudo stow -D wallpapers 2>/dev/null || true
        sudo stow -v --target /usr/share/wallpapers --restow wallpapers
    fi
}

generate_monitor_config() {
    local monitor_file="/etc/greetd/monitors.lua"
    sudo mkdir -p /etc/greetd
    if [ ! -f "$monitor_file" ]; then
        log "Generating system monitor override file (monitors.lua)..."
        sudo tee "$monitor_file" > /dev/null << 'EOF'
return {
    -- After login, arrange displays in Lumen (SUPER + SPACE → Display).
    -- Or edit this file and run: hyprctl reload
    -- mode: highres, highrr, preferred, or WxH@Hz (only one; Hyprland cannot combine them).
    -- Check connected outputs with: hyprctl monitors

    -- Laptop example:
    -- { name = "eDP-1", mode = "highrr", position = "auto", scale = 1, bitdepth = 8 },

    -- Desktop example (highrr = max refresh; Hyprland places outputs with auto):
    { name = "HDMI-A-1", mode = "highrr", position = "auto", scale = 1, bitdepth = 10 },
    { name = "DP-1", mode = "highrr", position = "auto", scale = 1, bitdepth = 10 }
}
EOF
        sudo chmod 644 "$monitor_file"
    fi
}

main() {
    sudo -v

    check_dependencies
    check_installer
    prompt_menu
    enable_multilib
    install_packages
    generate_monitor_config
    copy_etc
    stow_user
    stow_wallpapers
    
    echo ""
    success "Dotfiles installed successfully!"
    sub_log "Note: Some system changes may require a reboot or 'sudo systemctl daemon-reload'."
    sub_log "Configure monitors in /etc/greetd/monitors.lua, or after login use Lumen (SUPER + SPACE) → Display."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
