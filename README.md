# nrszero's Dotfiles

Arch Linux + Hyprland configuration files.

Managed with GNU Stow.

## Features

- **Hyprland** window manager with Lua configuration and per-monitor workspaces
- **Quickshell** QML-based UI (Status Bar, Login Screen, and Lock Screen)
  - Audio, Internet, Bluetooth, and Power widgets
  - OLED-optimized with auto-hiding UI
- **Wallpaper Slideshow** with custom keybinds using awww
- **Display Manager** using greetd with Hyprland integration
- **NVIDIA GPU Detection** - automatic GPU configuration (optional)
- **Neovim** Lua-based editor configuration with LSP and plugins
- **One-command Installation** with full automation

## Screenshots

|                                 Status Bar & Blurred Windows                                  |                                       Rofi App Launcher                                       |
| :-------------------------------------------------------------------------------------------: | :-------------------------------------------------------------------------------------------: |
| <img src="./assets/desktop.png" /> | <img src="./assets/app-launcher.png" /> |
|                                    **Popup Menu Buttons**                                     |                                    **Minimal Lockscreen**                                     |
| <img src="./assets/popup.png" /> | <img src="./assets/lock-screen.png" /> |

## 📦 Installation

### System Requirements

- **OS**: Arch Linux
- **Display Server**: Wayland
- **Optional**: NVIDIA GPU (auto-detected and configured)

### Prerequisites

Install `stow` and `yay` (AUR helper):

```bash
pacman -S --needed --noconfirm stow yay
```

### Quick Install

```bash
git clone https://github.com/nrszero/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

When prompted, **choose option 1** to install all required packages.

### What the Install Script Does

- Installs all required packages via pacman and yay
- Auto-detects NVIDIA GPU and configures accordingly
- Symlinks configurations to `~/.config` using stow
- Deploys system-wide configs to `/etc` (requires sudo)
- Installs wallpapers to `/usr/share/wallpapers`

### Post-Installation Configuration

**Important**: You may need to adjust your monitor configuration before first login.

Edit these files to match your display setup:
- `~/.config/hypr/hyprland.lua` - Hyprland monitor configuration
- `~/.config/greetd/hyprland.lua` - Login screen monitor configuration

Then redeploy system configs:

```bash
# Option 1: Skip package installation
SKIP_PACKAGES=1 ./install.sh

# Option 2: Run installer again and choose option 3
./install.sh  # then select "3) Skip packages, only deploy configs"
```

### Troubleshooting

**"Permission denied" on install.sh**
```bash
chmod +x ~/dotfiles/install.sh
```

**NVIDIA GPU not detected**
- Ensure NVIDIA drivers are installed: `pacman -S nvidia nvidia-utils`
- Run install script again

**Greeter/Lock screen not loading**
- Check monitor configuration in the post-install step above
- Verify greetd service is enabled: `sudo systemctl enable greetd`

## ⚙️ Configuration Highlights

### Hyprland (~/.config/hypr/)
- Custom per-monitor workspace keybinds
- Minimal animations
- Wallpaper-responsive terminal and window colors
- NVIDIA-specific optimizations (if applicable)

### Neovim (~/.config/nvim/)
- Plugin management
- LSP configuration
- Custom keymaps
- Performance optimizations

### Quickshell (~/.config/quickshell/)
- Custom Status Bar, Login Screen, and Lock Screen
- Status Bar widgets: Audio, Internet, Bluetooth, Power
- OLED-optimized with auto-hiding UI
