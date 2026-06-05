# nrszero's Dotfiles

Arch Linux + Hyprland configuration files.

Managed with GNU Stow.

## Features

- Hyprland window manager with Lua configuration
- Quickshell QML-based UI
- Wallpaper slideshow script using awww with Keybinds to change wallpapers
- Display manager using greetd
- Automatic NVIDIA GPU detection and configuration
- Clean separation of user (`~/.config`) and system (`/etc`) configs
- One-command installation

## 📦 Installation

### Prerequisites
- Arch Linux or Arch-based distribution
- `stow` for symlink management
- `yay` AUR helper installed

### Quick Start
```
git clone https://github.com/nrszero/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh

SKIP_PACKAGES=1 ./install.sh
```

### The script will:

- Install all packages from packages.txt
- Auto-detect NVIDIA GPU and configure accordingly
- Symlink configurations to ~/.config using stow
- Deploy system-wide configs to /etc
- Install wallpapers to /usr/share/wallpapers

## ⚙️ Configuration Highlights
### Hyprland (~/.config/hypr/)
Configuration featuring:
- Custom per monitor workspace keybinds
- Minimal Animations
- Wallpaper responsive terminal and window colors
- NVIDIA-specific optimizations (if applicable)

### Neovim (~/.config/nvim/)
Lua-based configuration featuring:
- Plugin management
- LSP configuration
- Custom keymaps
- Performance optimizations

### Quickshell (~/.config/quickshell/)
QML-based panel and widgets providing:
- Custom Status Bar and Control Panel and Login Screen
- Control Panel Widgets for Audio, Internet, and Bluetooth
- Built for OLEDs in mind. With auto-hiding UI
