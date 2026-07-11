-- 1. Dynamically get the current user's home directory
local home = os.getenv("HOME")

-- Fallback defaults (used if the file is missing or environment is broken)
local active_colors = {"rgba(5e81accc)", "rgba(5e81accc)"}
local inactive_colors = {"rgba(595959aa)"}

if home then
    -- Construct the dynamic path
    local wal_path = home .. "/.cache/wal/colors.lua"
    
    -- Load the file directly from disk
    local load_colors, err = loadfile(wal_path)

    if load_colors then
        local pywal = load_colors()

        -- Ensure the table actually contains data before applying
        if pywal and pywal.color10 then
            active_colors = {"rgb(" .. pywal.color8:sub(2) .. ")"}
            inactive_colors = {"rgba(" .. pywal.color0:sub(2) .. "aa)"}
        end
    else
        print("[Appearance] Pywal colors.lua failed to load from " .. wal_path .. ": " .. tostring(err))
    end
else
    print("[Appearance] ERROR: os.getenv('HOME') returned nil. Environment variables are missing.")
end

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 1,
        col = {
            active_border = { colors = active_colors },
            inactive_border = { colors = inactive_colors },
        },
        -- Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
})

hl.config({
    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 8,
            passes = 5,
            vibrancy = 0.1696,
            brightness = 0.7,
            popups = true,
            popups_ignorealpha = 0.1,
            new_optimizations = true,
        },
    },
})

hl.config({
    cursor = {
        no_hardware_cursors = true,
    },
})

hl.curve("simple", {
    type = "bezier",
    points = { {0.16, 1}, {0.3, 1} }
})

-- Speed is in ds (1ds = 100ms), so speed = 1 is exactly 0.1 seconds.
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "simple" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "simple" })
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "simple" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 1, bezier = "simple" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "simple" })
hl.animation({ leaf = "workspaces", enabled = false })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})

hl.window_rule({
    name  = "windowrule-1",
    match = {
        class = ".*",
    },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "windowrule-2",
    match = {
        class = "^$",
        title = "^$",
        xwayland = 1,
        float = 1,
        fullscreen = 0,
        pin = 0,
    },
    no_focus = true,
})

-- Kitty autostart rules
hl.window_rule({
    name = "kitty-autostart",
    match = { 
        class = "^(kitty-autostart)$",
    },
    float = true,
    size = { 800, 350 },
    move = { 10, "(monitor_h - 360)"},
})


hl.window_rule({
    name  = "windowrule-3",
    match = {
        class = "^(steam)$",
    },
    tile = true,
})

hl.window_rule({
    name  = "windowrule-4",
    match = {
        class = "^(steam)$",
        title = "negative:^(Steam)$",
    },
    float = true,
})

hl.window_rule({
    name  = "windowrule-5",
    match = {
        class = "^(org.pulseaudio.pavucontrol)$",
    },
    opacity = 0.80,
})

-- 1. Float all Unity windows by default so tiny menus don't tile
hl.window_rule({
    name  = "unity-float-all",
    match = {
        class = "^(Unity)$",
    },
    float = 1,
})

-- 2. Tile the main Unity Editor window (overrides the rule above)
hl.window_rule({
    name  = "unity-tile-main",
    match = {
        class = "^(Unity)$",
        title = "^(Unity- . *)$",
    },
    float = 0,
})

-- 3. Fix tiny/unclickable drop-down menus (like "Add Component")
hl.window_rule({
    name  = "unity-dropdown-advanced",
    match = {
        initial_title = "(UnityEditor.IMGUI.Controls.AdvancedDropdownWindow)",
    },
    min_size = { 300, 200 },
})

hl.window_rule({
    name  = "unity-dropdown-add-component",
    match = {
        initial_title = "(UnityEditor.AddComponent.AddComponentWindow)",
    },
    min_size = { 230, 200 },
})

hl.window_rule({
    name  = "unity-dropdown-filter",
    match = {
        initial_title = "(UnityEditor.Rendering.FilterWindow)",
    },
    min_size = { 230, 200 },
})

-- 4. Prevent tooltips from stealing window focus
hl.window_rule({
    name  = "unity-tooltip-focus",
    match = {
        class = "^(Unity)$",
        title = "^(UnityTooltipWindow)$",
    },
    no_initial_focus = 1,
})

-- Float Unity windows that have no title (Drag proxies and hidden X11 payloads)
hl.window_rule({
    name  = "unity-drag-proxy-empty",
    match = {
        class = "^(Unity)$",
        title = "^$",
    },
    float = 1,
    no_initial_focus = 1,
    no_anim = 1,
    min_size = { 1, 1 },
})

-- Float windows titled exactly "Unity" 
hl.window_rule({
    name  = "unity-drag-proxy-exact",
    match = {
        class = "^(Unity)$",
        title = "^(Unity)$",
    },
    float = 1,
    no_initial_focus = 1,
    no_anim = 1,
    min_size = { 1, 1 },
})

-- Float compilation and loading progress bars
hl.window_rule({
    name  = "unity-progress-bars",
    match = {
        class = "^(Unity)$",
        title = "^(Compiling|Reloading|Hold on|Importing|Building).*$",
    },
    float = 1,
    no_initial_focus = 1,
    center = 1,
})

hl.layer_rule({
    match = {
        namespace = "rofi",
    },
    blur = true,
    ignore_alpha = 0.1,
})

hl.layer_rule({
    match = {
        namespace = "quickshell",
    },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.1,
})

hl.layer_rule({
    match = {
        namespace = "chrome",
    },
    blur = true,
})

hl.config({
    debug = {
        disable_logs = false,
        enable_stdout_logs = false,
    },
})
