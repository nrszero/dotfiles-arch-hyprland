
LEFT_MONITOR = "HDMI-A-1"
RIGHT_MONITOR = "DP-1"

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("/etc/awww/awww_randomize.sh")
    hl.exec_cmd("quickshell -p /etc/greetd/QuickshellGreeter.qml > /var/tmp/quickshell-greeter.log 2>&1; hyprctl dispatch exit")
end)

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

