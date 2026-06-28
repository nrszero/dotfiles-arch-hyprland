-- Main
hl.bind(MAIN_MOD .. " + T", hl.dsp.exec_cmd(TERMINAL), { description = "Open Terminal" })
hl.bind(MAIN_MOD .. " + SPACE", hl.dsp.exec_cmd(MENU), { description = "Open App Launcher" })
hl.bind(MAIN_MOD .. " + E", hl.dsp.exec_cmd(FILE_MANAGER), { description = "Open File Manager" })
hl.bind(MAIN_MOD .. " + C", hl.dsp.window.close(), { description = "Close active window" })
hl.bind(MAIN_MOD .. " + B", hl.dsp.exec_cmd(BROWSER), { description = "Open Browser" })
hl.bind(MAIN_MOD .. " + A", hl.dsp.exec_cmd("pavucontrol"), { description = "Open Audio Control" })
hl.bind(MAIN_MOD .. " + D", hl.dsp.exec_cmd("discord"), { description = "Open Discord" })
hl.bind(MAIN_MOD .. " + G", hl.dsp.exec_cmd("lutris"), { description = "Open Lutris" })
hl.bind(MAIN_MOD .. " + N", hl.dsp.exec_cmd("kill $(cat $XDG_RUNTIME_DIR/awww_sleep.pid) 2>/dev/null"), { description = "Next wallpaper" })
hl.bind(MAIN_MOD .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/cycle_wallpaper_folder.sh"), { description = "Next wallpaper folder" })
hl.bind(MAIN_MOD .. " + Tab", hl.dsp.global("quickshell:toggleBar"), { description = "Toggle autohide status bar" })
hl.bind(MAIN_MOD .. " + M", hl.dsp.exec_cmd("~/.config/quickshell/lock/lock.sh"), { description = "Lock screen" })
hl.bind(MAIN_MOD .. " + SHIFT + M", hl.dsp.exit(), { description = "Exit Hyprland" })

-- Layout
hl.bind(MAIN_MOD .. " + V", hl.dsp.window.float(), { description = "Toggle window floating" })
hl.bind(MAIN_MOD .. " + P", hl.dsp.window.pseudo(), { description = "Toggle pseudo-tiling" })
hl.bind(MAIN_MOD .. " + O", hl.dsp.layout("togglesplit"), { description = "Toggle split layout" })
hl.bind(MAIN_MOD .. " + F", hl.dsp.window.fullscreen(), { description = "Toggle fullscreen" })


-- Screenshots
hl.bind(MAIN_MOD .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window"), { description = "Screenshot active window" })
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output"), { description = "Screenshot entire monitor" })
--hl.bind("$shiftMod" .. " + " .. "PRINT", hl.dsp.exec_cmd("hyprshot -m region"), { description = "Screenshot region" })

-- Focus window
hl.bind(MAIN_MOD .. " + H", hl.dsp.focus({ direction = "l" }), { description = "Focus left" })
hl.bind(MAIN_MOD .. " + L", hl.dsp.focus({ direction = "r" }), { description = "Focus right" })
hl.bind(MAIN_MOD .. " + K", hl.dsp.focus({ direction = "u" }), { description = "Focus up" })
hl.bind(MAIN_MOD .. " + J", hl.dsp.focus({ direction = "d" }), { description = "Focus down" })

-- Move active windows
hl.bind(MAIN_MOD .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }), { description = "Move window left" })
hl.bind(MAIN_MOD .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }), { description = "Move window right" })
hl.bind(MAIN_MOD .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }), { description = "Move window up" })
hl.bind(MAIN_MOD .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }), { description = "Move window down" })

-- Move active window to a workspace
for i = 0, WORKSPACES do
    hl.bind(MAIN_MOD .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
end

-- Switch workspaces
for i = 0, WORKSPACES do
    hl.bind(MAIN_MOD .. " + " .. i, hl.dsp.focus({ workspace = i }), { description = "Switch to workspace " .. i })
end

-- Standard special workspace (scratchpad). Can also be used to hide fullscreen games.
hl.bind(MAIN_MOD .. " + S", hl.dsp.workspace.toggle_special("magic"), { description = "Toggle magic workspace" })
hl.bind(MAIN_MOD .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic"}), { description = "Move window to magic workspace" })
hl.bind(MAIN_MOD .. " + SHIFT + S", hl.dsp.workspace.toggle_special("magic"))

-- Move/resize windows with MAIN_MOD + LMB/RMB and dragging
hl.bind(MAIN_MOD .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window" })
hl.bind(MAIN_MOD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, description = "Raise volume" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, description = "Lower volume" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, description = "Toggle mute" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Toggle mic mute" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, description = "Raise brightness" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, description = "Lower brightness" })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/Pause media" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/Pause media" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })

-- Global Mute Key
hl.bind("CTRL + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Global mic toggle" })
