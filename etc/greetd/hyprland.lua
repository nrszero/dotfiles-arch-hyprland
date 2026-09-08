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
LEFT_MONITOR = outputs[1] and outputs[1].name or ""
RIGHT_MONITOR = outputs[#outputs] and outputs[#outputs].name or LEFT_MONITOR

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("/etc/awww/awww_randomize.sh")
    hl.exec_cmd("quickshell -p /etc/greetd/QuickshellGreeter.qml >> /var/tmp/quickshell-greeter.log 2>&1; hyprctl dispatch exit")
end)

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

hl.config({
    decoration = {
        blur = {
            enabled = true,
            size = 8,
            passes = 5,
            vibrancy = 0.1696,
            brightness = 0.7,
            popups = true,
            popups_ignorealpha = 0.1,
        },
    },
    cursor = {
        default_monitor = LEFT_MONITOR,
    },
})

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_hyprland_guiutils_check = true,
    },
})

hl.layer_rule({
    match = {
        namespace = "quickshell",
    },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.1,
})
