# nrszero's Dotfiles

Arch Linux + Hyprland configuration files.

Managed with GNU Stow.

## Features

- Hyprland window manager with Lua configuration
- Quickshell QML-based UI (Status Bar, Login Screen, and Lock Screen)
- Wallpaper slideshow script using awww with Keybinds to change wallpapers
- Display manager using greetd
- Automatic NVIDIA GPU detection and configuration
- One-command installation

## 📦 Installation

### Prerequisites
```
pacman -S --needed --noconfirm stow 
pacman -S --needed --noconfirm yay
```

### Script Functions

- Installs required packages
- Auto-detect NVIDIA GPU and configure accordingly
- Symlink configurations to ~/.config using stow
- Deploy system-wide configs to /etc
- Install wallpapers to /usr/share/wallpapers

### Script Quick Start
```
git clone https://github.com/nrszero/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```
- Choose package installation option 1) to make sure you have everything required.

### After Install

- Adjust monitor config to fit your system in the following files
    - ~/dotfiles/.config/hypr/hyprland.lua
    - ~/dotfiles/etc/greetd/hyprland.lua
- Then update the file in /etc by doing either of the following
    - SKIP_PACKAGES=1 ./install.sh
    - ./install.sh' and package installation option 3)

## Screenshots

|                                 Status Bar & Blurred Windows                                  |                                       Rofi App Launcher                                       |
| :-------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------: |
| <img src="./assets/desktop.png" /> | <img src="./assets/app-launcher.png" /> |
|                                    **Popup Menu Buttons**                                     |                                    **Minimal Lockscreen**                                     |
| <img src="./assets/popup.png" /> | <img src="./assets/lock-screen.png" /> |

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
- Custom Status Bar, Login Screen, and Lock Screen
- Status Bar widgets for Audio, Internet, and Bluetooth, and Power
- Built for OLEDs in mind. With auto-hiding UI
