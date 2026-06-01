---@module 'hl'

MAIN_MOD = "SUPER"
TERMINAL = "kitty"
BROWSER = "google-chrome-stable --ozone-platform=wayland --ozone-platform-hint=auto"
FILE_MANAGER = "kitty yazi"
MENU = "rofi -show combi -modes combi -combi-modes drun,run"
WORKSPACES = 6

require("modules.autostart")
require("modules.input")
require("modules.appearance")
require("modules.keybinds")
require("modules.workspaces")

------------------
---- MONITORS ----
------------------
-- See https://wiki.hypr.land/Configuring/Monitors/

hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = 1,
    bitdepth = 10,
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

