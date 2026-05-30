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
  log "Stowing user configs..."
  for pkg in hypr quickshell kitty nvim rofi yazi fastfetch mangohud wal btop mpv; do
    if [ -d "$DOTFILES/$pkg" ]; then
      stow -v -t ~ --restow --adopt "$pkg"
    fi
  done
}

stow_system() {
  log "Stowing system files (greetd)..."
  if [ -d "$DOTFILES/etc" ]; then
    sudo stow -v -t / --restow --adopt etc
  fi
}

main() {
  install_packages
  stow_user
  stow_system
  log "✅ Dotfiles installed! Reboot or run hyprctl reload"
}

main "$@"
