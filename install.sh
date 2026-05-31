#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '==> %s\n' "$*"; }

install_packages() {
  if [[ "${SKIP_PACKAGES:-0}" == "1" ]]; then return; fi
  log "Installing packages from packages.txt..."
  yay -S --needed --noconfirm - < "$DOTFILES/packages.txt"
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
  log "✅ Dotfiles installed! Reboot or run hyprctl reload"
}

main "$@"
