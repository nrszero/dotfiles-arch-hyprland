---@module 'hl'

MAIN_MOD = "SUPER"
TERMINAL = "kitty"
BROWSER = "google-chrome-stable --ozone-platform=wayland --ozone-platform-hint=auto"
FILE_MANAGER = "kitty yazi"
MENU = "rofi -show combi -modes combi -combi-modes drun,run"
WORKSPACES = 4

require("modules.autostart")
require("modules.input")
require("modules.appearance")
require("modules.keybinds")

------------------
---- MONITORS ----
------------------
local monitor0 = "HDMI-A-1"
local monitor1 = "DP-1"

-- See https://wiki.hypr.land/Configuring/Monitors/

hl.monitor({
    output   = monitor0,
    mode     = "2560x1440@360",
    position = "0x0",
    scale    = 1,
    bitdepth = 10,
})

hl.monitor({
    output   = monitor1,
    mode     = "2560x1440@360",
    position = "2560x0",
    scale    = 1,
    bitdepth = 10,
})

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
-- See https://wiki.hypr.land/Configuring/Environment-variables/

hl.env("XCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_SIZE", 24)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("GTK_THEME", "Adwaita-dark")
hl.env("EDITOR", "nvim")

