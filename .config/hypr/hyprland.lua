---@module 'hl'

MAIN_MOD = "SUPER"
TERMINAL = "kitty"
BROWSER = "google-chrome-stable --ozone-platform=wayland --ozone-platform-hint=auto"
FILE_MANAGER = "kitty yazi"
WS_PER_MONITOR = 3

local function parse_xy(pos)
    if type(pos) ~= "string" then
        return 0, 0
    end
    local x, y = pos:match("^(%-?%d+)x(%-?%d+)$")
    return tonumber(x) or 0, tonumber(y) or 0
end

local function outputs_from_config(monitors)
    local list = {}
    for _, m in ipairs(monitors) do
        if type(m) == "table" and m.name then
            table.insert(list, m)
        end
    end
    table.sort(list, function(a, b)
        local ax, ay = parse_xy(a.position)
        local bx, by = parse_xy(b.position)
        if ax ~= bx then
            return ax < bx
        end
        return ay < by
    end)
    return list
end

local monitors = dofile("/etc/greetd/monitors.lua")
local outputs = outputs_from_config(monitors)
MONITOR_LAYOUT = {}
for _, m in ipairs(outputs) do
    MONITOR_LAYOUT[#MONITOR_LAYOUT + 1] = m.name
end
LEFT_MONITOR = MONITOR_LAYOUT[1] or ""
RIGHT_MONITOR = MONITOR_LAYOUT[#MONITOR_LAYOUT] or LEFT_MONITOR

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
-- mode is one of: highres, highrr, preferred, or WxH@Hz (Hyprland cannot combine keywords).

for _, m in ipairs(outputs) do
    hl.monitor({
        output   = m.name,
        mode     = m.mode or "highrr",
        position = m.position or "auto",
        scale    = m.scale or 1,
        bitdepth = m.bitdepth or 8,
    })
end

-- Fallback for any other random monitors you plug in
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto",
    scale    = 1,
})
