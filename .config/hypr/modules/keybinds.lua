-- General
hl.bind(MAIN_MOD .. " + C", hl.dsp.window.close())
hl.bind(MAIN_MOD .. " + M", hl.dsp.exit())
hl.bind(MAIN_MOD .. " + V", hl.dsp.window.float())
hl.bind(MAIN_MOD .. " + P", hl.dsp.window.pseudo())
hl.bind(MAIN_MOD .. " + O", hl.dsp.layout("togglesplit"))
hl.bind(MAIN_MOD .. " + F", hl.dsp.window.fullscreen())
hl.bind(MAIN_MOD .. " + N", hl.dsp.exec_cmd("kill $(cat /tmp/awww_sleep_$(whoami).pid) 2>/dev/null"))
hl.bind(MAIN_MOD .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/cycle_wallpaper_folder.sh"))

-- Application keybinds
hl.bind(MAIN_MOD .. " + T", hl.dsp.exec_cmd(TERMINAL))
hl.bind(MAIN_MOD .. " + E", hl.dsp.exec_cmd(FILE_MANAGER))
hl.bind(MAIN_MOD .. " + B", hl.dsp.exec_cmd(BROWSER))
hl.bind(MAIN_MOD .. " + A", hl.dsp.exec_cmd("pavucontrol"))
hl.bind(MAIN_MOD .. " + D", hl.dsp.exec_cmd("discord"))
hl.bind(MAIN_MOD .. " + SPACE", hl.dsp.exec_cmd(MENU))
hl.bind(MAIN_MOD .. " + G", hl.dsp.exec_cmd("lutris"))

-- Screenshots
hl.bind(MAIN_MOD .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output"))
--hl.bind("$shiftMod" .. " + " .. "PRINT", hl.dsp.exec_cmd("hyprshot -m region"))

-- Focus window
hl.bind(MAIN_MOD .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(MAIN_MOD .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(MAIN_MOD .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(MAIN_MOD .. " + J", hl.dsp.focus({ direction = "d" }))

-- Move active windows
hl.bind(MAIN_MOD .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(MAIN_MOD .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(MAIN_MOD .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(MAIN_MOD .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

-- Move active window to a workspace
hl.bind(MAIN_MOD .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(MAIN_MOD .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(MAIN_MOD .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(MAIN_MOD .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))

-- Switch workspaces
for i = 0, WORKSPACES do
    hl.bind(MAIN_MOD .. " + " .. i, hl.dsp.focus({ workspace = i }))
end

-- Standard special workspace (scratchpad). Can also be used to hide fullscreen games.
hl.bind(MAIN_MOD .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(MAIN_MOD .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic"}))
hl.bind(MAIN_MOD .. " + SHIFT + S", hl.dsp.workspace.toggle_special("magic"))

-- Move/resize windows with MAIN_MOD + LMB/RMB and dragging
hl.bind(MAIN_MOD .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(MAIN_MOD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Global Keybind for quickshell
for i = 0, WORKSPACES do
    hl.bind(MAIN_MOD .. " + " .. i, hl.dsp.global("quickshell:toggleBar"))
end
hl.bind(MAIN_MOD .. " + S", hl.dsp.global("quickshell:toggleBar"))
hl.bind(MAIN_MOD .. " + Tab", hl.dsp.global("quickshell:togglePanel"))

-- Disable DP-1 for Moonlight remote sessions
hl.bind(MAIN_MOD .. " + U", hl.dsp.exec_cmd("hyprctl keyword monitor DP-1"))

-- Reload Hyprland config to restore dual monitors
hl.bind(MAIN_MOD .. " + SHIFT + U", hl.dsp.exec_cmd("hyprctl reload"))

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Global Mute Key
hl.bind("CTRL + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
