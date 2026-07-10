---@module 'hl'

MAIN_MOD = "SUPER"
TERMINAL = "kitty"
BROWSER = "google-chrome-stable --ozone-platform=wayland --ozone-platform-hint=auto"
FILE_MANAGER = "kitty yazi"
MENU = "rofi -show combi -modes combi -combi-modes drun,run"
WORKSPACES = 6 -- Move windows to a workspace that will exist if making value smaller.

local monitors = dofile("/etc/greetd/monitors.lua")
LEFT_MONITOR = monitors.primary and monitors.primary.name or ""
RIGHT_MONITOR = monitors.secondary and monitors.secondary.name or ""

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

if monitors.primary then
    hl.monitor({
        output   = monitors.primary.name,
        mode     = monitors.primary.mode or "preferred",
        position = monitors.primary.position or "auto",
        scale    = monitors.primary.scale or 1,
        bitdepth = monitors.primary.bitdepth or 8,
    })
end

if monitors.secondary then
    hl.monitor({
        output   = monitors.secondary.name,
        mode     = monitors.secondary.mode or "preferred",
        position = monitors.secondary.position or "auto",
        scale    = monitors.secondary.scale or 1,
        bitdepth = monitors.secondary.bitdepth or 8,
    })
end

-- Fallback for any other random monitors you plug in
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

