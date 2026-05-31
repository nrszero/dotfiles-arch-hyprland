# nrszero's Dotfiles

Arch Linux + Hyprland configuration files.

Managed with GNU Stow. Includes a custom Quickshell greeter running under greetd.

## Features

- Hyprland window manager with Lua configuration
- greetd + Hyprland + Quickshell login screen
- awww wallpaper daemon with randomizer on login
- Clean separation of user (`~/.config`) and system (`/etc`) configs
- One-command installation

## Installation

```bash
git clone https://github.com/nrszero/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh

To skip package installation:
SKIP_PACKAGES=1 ./install.sh
```
```bash
Repository Structure
text.
├── .config/          # User configs → ~/.config/
├── etc/              # System configs → /etc/ (greetd)
├── wallpapers/       # Wallpapers → /usr/share/wallpapers
├── install.sh
├── packages.txt
└── README.md
```
