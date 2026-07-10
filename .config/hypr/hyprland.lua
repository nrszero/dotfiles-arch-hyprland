---@module 'hl'

MAIN_MOD = "SUPER"
TERMINAL = "kitty"
BROWSER = "google-chrome-stable --ozone-platform=wayland --ozone-platform-hint=auto"
FILE_MANAGER = "kitty yazi"
MENU = "rofi -show combi -modes combi -combi-modes drun,run"
WORKSPACES = 6 -- Move windows to a workspace that will exist if making value smaller.

local monitors = dofile("/etc/greetd/monitors.lua")
LEFT_MONITOR = monitors.LEFT_MONITOR
RIGHT_MONITOR = monitors.RIGHT_MONITOR

require("modules.autostart")
require("modules.input")
require("modules.appearance")
require("modules.keybinds")
require("modules.workspaces")
require("modules.environment")

------------------
---- MONITORS ----
------------------
-- See https://wiki.hypr.land/Configuring/Monitors/

hl.monitor({
    output   = LEFT_MONITOR,
    mode     = "highrr",
    position = "0x0",
    scale    = 1,
    bitdepth = 10,
})

hl.monitor({
    output   = RIGHT_MONITOR,
    mode     = "highrr",
    position = "2560x0",
    scale    = 1,
    bitdepth = 10,
})

-- Fallback for any other random monitors you plug in
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

