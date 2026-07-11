local monitors = dofile("/etc/greetd/monitors.lua")
LEFT_MONITOR = monitors.primary and monitors.primary.name or ""
RIGHT_MONITOR = monitors.secondary and monitors.secondary.name or ""

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("/etc/awww/awww_randomize.sh")
    hl.exec_cmd("quickshell -p /etc/greetd/QuickshellGreeter.qml >> /var/tmp/quickshell-greeter.log 2>&1; hyprctl dispatch exit")
end)

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

