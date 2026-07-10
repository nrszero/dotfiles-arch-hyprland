#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    ' "$DOTFILES/requirements.txt"
}

check_dependencies() {
    log "Checking prerequisites..."
    local deps=("git" "stow" "yay")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            warn "'$dep' is not installed. Please install it before running this script."
            exit 1
        fi
    done
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
    
    log "Parsing packages from requirements.txt..."
    
    # Read packages into an array safely
    mapfile -t req_pkgs < <(get_packages "required")
    
    if [[ "$INSTALL_MODE" == "full" ]]; then
        mapfile -t full_pkgs < <(get_packages "full")
        req_pkgs+=("${full_pkgs[@]}")
    fi

    # Pass the array to yay
    yay -S --needed --noconfirm "${req_pkgs[@]}"

    config_system

    success "All packages installed and system configured."
}

config_system() {
    # Check if an Nvidia GPU is present
    if lspci | grep -iE 'vga|3d' | grep -iq 'nvidia'; then
        sub_log "NVIDIA GPU detected."

        sub_log "Installing NVIDIA packages from requirements.txt"
        mapfile -t nvidia_pkgs < <(get_packages "nvidia")
        yay -S --needed --noconfirm "${nvidia_pkgs[@]}"

        sub_log "Enabling Wayland sleep services..."
        sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
                
        # Append kernel parameter if not already present
        if ! grep -q "NVreg_PreserveVideoMemoryAllocations" /etc/default/grub; then
            sub_log "Adding NVreg_PreserveVideoMemoryAllocations to GRUB..."
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&nvidia.NVreg_PreserveVideoMemoryAllocations=1 /' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
        if ! grep -q "nvidia_drm.modeset" /etc/default/grub; then
            sub_log "Adding nvidia_drm.modeset to GRUB..."
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&nvidia_drm.modeset=1 /' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
    else
        sub_log "Non-NVIDIA GPU detected (AMD/Intel). Skipping proprietary sleep hooks."
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
    local target_dir="$HOME/.config"
    local backup_dir="$HOME/.config.bak/$(date +%Y%m%d_%H%M%S)"
    local made_backup=0

    # Ensure the repo has a .config directory before trying to read it
    if [ -d "$DOTFILES/.config" ]; then
        # Enable dotglob to include hidden files/folders in the loop, nullglob to prevent literal '*' if empty
        shopt -s dotglob nullglob
        
        for item in "$DOTFILES/.config"/*; do
            local base_item=$(basename "$item")
            local target_item="$target_dir/$base_item"

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
    stow -v --target "$target_dir" --restow .config
}

stow_wallpapers() {
    log "Stowing wallpapers to /usr/share/wallpapers..."
    if [ -d "$DOTFILES/wallpapers" ]; then
        sudo mkdir -p /usr/share/wallpapers
        sudo stow -D wallpapers 2>/dev/null || true
        sudo stow -v --target /usr/share/wallpapers --restow wallpapers
    fi
}

generate_local_config() {
    local monitor_file="$DOTFILES/etc/greetd/monitors.lua"
    if [ ! -f "$monitor_file" ]; then
        log "Generating system monitor override file (monitors.lua)..."
        cat << 'EOF' > "$monitor_file"
return {
    LEFT_MONITOR = "HDMI-A-1",
    RIGHT_MONITOR = "DP-1"
}
EOF
        sudo chmod 644 "$monitor_file"
    fi
}

main() {
    sudo -v

    check_dependencies
    prompt_menu
    enable_multilib
    install_packages
    generate_local_config
    copy_etc
    stow_user
    stow_wallpapers
    
    echo ""
    success "Dotfiles installed successfully!"
    log "Note: Some system changes may require a reboot or 'sudo systemctl daemon-reload'."
}

main "$@"
