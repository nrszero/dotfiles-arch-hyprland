#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '==> %s\n' "$*"; }

install_packages() {
    if [[ "${SKIP_PACKAGES:-0}" == "1" ]]; then return; fi
    log "Installing packages from packages.txt..."

    yay -S --needed --noconfirm - < "$DOTFILES/packages.txt"

    config_system
}

config_system() {
    # Check if an Nvidia GPU is present
    if lspci | grep -iE 'vga|3d' | grep -iq 'nvidia'; then
        log "-> NVIDIA GPU detected."
        log "-> Enabling Wayland sleep services..."
        sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

        log "-> Installing packages from packages_nvidia.txt"
        yay -S --needed --noconfirm - < "$DOTFILES/packages_nvidia.txt"
        
        # Append kernel parameter if not already present
        if ! grep -q "NVreg_PreserveVideoMemoryAllocations" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&nvidia.NVreg_PreserveVideoMemoryAllocations=1 /' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
        if ! grep -q "nvidia_drm.modeset" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&nvidia_drm.modeset=1 /' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
    else
        log "-> Non-NVIDIA GPU detected (AMD/Intel). Skipping proprietary sleep hooks."
    fi
}

stow_user() {
    log "Stowing user configs (.config/)..."
    stow -v --target ~/.config --restow --adopt .config
}
 
stow_system() {
    log "Stowing system files (etc/)..."
    if [ -d "$DOTFILES/etc" ]; then
        chmod o+rx "$HOME"
        chmod -R 755 "$DOTFILES/etc"
        chmod -R 755 "$DOTFILES/wallpapers"
        chmod o+rx "$DOTFILES"

        sudo stow -D etc 2>/dev/null || true
        sudo stow -v --target /etc --restow --adopt etc
        
        sudo mkdir -p /usr/share/wallpapers
        sudo stow -D wallpapers 2>/dev/null || true
        sudo stow -v --target /usr/share/wallpapers --restow --adopt wallpapers
        
      fi
}

main() {
      install_packages
      stow_user
      stow_system
      log "Dotfiles installed! Reboot or run hyprctl reload"
}

main "$@"
