-- Local 1–3 workspaces per monitor (layout order: x, then y).
-- SUPER+1 is always this screen's first workspace.

local per = WS_PER_MONITOR or 3
local adopt_tries = 0

local function sorted_monitors()
    local ok, mons = pcall(hl.get_monitors)
    if not ok or type(mons) ~= "table" then
        return {}
    end
    local list = {}
    for _, m in ipairs(mons) do
        if m and m.name then
            table.insert(list, m)
        end
    end
    table.sort(list, function(a, b)
        local ax, ay = a.x or 0, a.y or 0
        local bx, by = b.x or 0, b.y or 0
        if ax ~= bx then
            return ax < bx
        end
        if ay ~= by then
            return ay < by
        end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

local function has_distinct_layout(mons)
    if #mons <= 1 then
        return true
    end
    for i = 2, #mons do
        if (mons[i].x or 0) ~= (mons[1].x or 0) or (mons[i].y or 0) ~= (mons[1].y or 0) then
            return true
        end
    end
    return false
end

local function layout_index_of(mon)
    if not mon then
        return 0
    end
    local mons = sorted_monitors()
    for i, m in ipairs(mons) do
        if m.name == mon.name then
            return i - 1
        end
    end
    return 0
end

local function local_index(ws)
    if not ws then
        return 1
    end
    local id = ws.id or 1
    local idx = id % per
    if idx == 0 then
        idx = per
    end
    return idx
end

local function global_id(mon_index, loc)
    return mon_index * per + loc
end

local function target_monitor()
    local ok, mon = pcall(hl.get_monitor_at_cursor)
    if ok and mon then
        return mon
    end
    return hl.get_active_monitor()
end

local function workspace_windows(ws)
    if not ws then
        return {}
    end
    local ok, wins = pcall(function()
        return hl.get_workspace_windows(ws)
    end)
    if ok and type(wins) == "table" then
        return wins
    end
    ok, wins = pcall(function()
        return ws:get_windows()
    end)
    if ok and type(wins) == "table" then
        return wins
    end
    return {}
end

local function move_windows_to(ws, dest_gid)
    for _, win in ipairs(workspace_windows(ws)) do
        hl.dispatch(hl.dsp.window.move({
            workspace = tostring(dest_gid),
            window = win,
        }))
    end
end

local function setup_dynamic_workspaces()
    local mons = sorted_monitors()
    for i, mon in ipairs(mons) do
        local idx = i - 1
        for loc = 1, per do
            hl.workspace_rule({
                workspace = tostring(global_id(idx, loc)),
                monitor = mon.name,
                persistent = true,
                default = (loc == 1),
            })
        end
    end
end

-- Hyprland still creates 1, 2, 3… across monitors before rules stick. Pull
-- stray windows onto this screen's 1–3 and show the default local workspace.
local function adopt_monitor(mon, idx)
    local lo, hi = global_id(idx, 1), global_id(idx, per)
    local current = mon.active_workspace
    local cid = current and tonumber(current.id) or 0
    local in_range = cid >= lo and cid <= hi
    local dest = in_range and cid or lo

    local ok, wss = pcall(hl.get_workspaces)
    if ok and type(wss) == "table" then
        for _, ws in ipairs(wss) do
            if ws and not ws.special and ws.monitor and ws.monitor.name == mon.name then
                local id = tonumber(ws.id) or 0
                if id > 0 and (id < lo or id > hi) then
                    move_windows_to(ws, dest)
                end
            end
        end
    end

    if not in_range then
        hl.dispatch(hl.dsp.focus({ monitor = mon.name }))
        hl.dispatch(hl.dsp.focus({
            workspace = tostring(dest),
            on_current_monitor = true,
        }))
    end
end

local function adopt_monitors()
    local mons = sorted_monitors()
    if #mons == 0 then
        return
    end
    local keep = hl.get_active_monitor()
    for i, mon in ipairs(mons) do
        adopt_monitor(mon, i - 1)
    end
    if keep then
        hl.dispatch(hl.dsp.focus({ monitor = keep.name }))
    end
end

local function schedule_adopt()
    hl.timer(function()
        adopt_tries = adopt_tries + 1
        local mons = sorted_monitors()
        local ready = #mons > 0 and (has_distinct_layout(mons) or adopt_tries >= 20)
        if not ready then
            schedule_adopt()
            return
        end
        adopt_tries = 0
        setup_dynamic_workspaces()
        adopt_monitors()
    end, { timeout = 50, type = "oneshot" })
end

hl.on("hyprland.start", function()
    setup_dynamic_workspaces()
    adopt_tries = 0
    schedule_adopt()
end)
hl.on("monitor.added", function()
    setup_dynamic_workspaces()
    adopt_tries = 0
    schedule_adopt()
end)
hl.on("monitor.removed", setup_dynamic_workspaces)
hl.on("config.reloaded", function()
    adopt_tries = 0
    setup_dynamic_workspaces()
    schedule_adopt()
end)

setup_dynamic_workspaces()
schedule_adopt()

local function activate_local(loc)
    return function()
        local mon = target_monitor()
        if not mon then
            return
        end
        local idx = layout_index_of(mon)
        local gid = global_id(idx, loc)
        local lo, hi = global_id(idx, 1), global_id(idx, per)
        local current = mon.active_workspace
        local cid = current and tonumber(current.id) or 0
        if current and (cid < lo or cid > hi) then
            move_windows_to(current, gid)
        end
        hl.dispatch(hl.dsp.focus({ monitor = mon.name }))
        hl.dispatch(hl.dsp.focus({
            workspace = tostring(gid),
            on_current_monitor = true,
        }))
    end
end

local function move_to_local(loc)
    return function()
        local mon = target_monitor()
        if not mon then
            return
        end
        local gid = global_id(layout_index_of(mon), loc)
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(gid) }))
    end
end

for i = 1, per do
    hl.bind(MAIN_MOD .. " + " .. i, activate_local(i), { description = "Switch to local workspace " .. i })
    hl.bind(MAIN_MOD .. " + SHIFT + " .. i, move_to_local(i), { description = "Move window to local workspace " .. i })
end

local function move_window_dir(dir)
    return function()
        local win = hl.get_active_window()
        if not win then
            return
        end
        local src_name = win.monitor and win.monitor.name or nil
        local dest_ws = {}
        for _, m in ipairs(sorted_monitors()) do
            local ws = m.active_workspace
            if m.name and ws and ws.id then
                dest_ws[m.name] = ws.id
            end
        end
        hl.dispatch(hl.dsp.window.move({ direction = dir }))
        hl.timer(function()
            local w = hl.get_active_window()
            if not w or not w.monitor or not src_name then
                return
            end
            if w.monitor.name == src_name then
                return
            end
            local gid = dest_ws[w.monitor.name]
            if not gid then
                local aw = w.monitor.active_workspace
                gid = aw and aw.id or global_id(layout_index_of(w.monitor), 1)
            end
            hl.dispatch(hl.dsp.window.move({ workspace = tostring(gid) }))
        end, { timeout = 30, type = "oneshot" })
    end
end

hl.bind(MAIN_MOD .. " + SHIFT + H", move_window_dir("l"), { description = "Move window left" })
hl.bind(MAIN_MOD .. " + SHIFT + L", move_window_dir("r"), { description = "Move window right" })
hl.bind(MAIN_MOD .. " + SHIFT + K", move_window_dir("u"), { description = "Move window up" })
hl.bind(MAIN_MOD .. " + SHIFT + J", move_window_dir("d"), { description = "Move window down" })
