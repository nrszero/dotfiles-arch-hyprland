-- First half of workspaces → leftmost monitor
-- Second half → rightmost monitor
-- Survives ANY monitor name change, new monitors, different ports, etc.

local function setup_dynamic_workspaces()
    local total = WORKSPACES or 6
    local half  = math.ceil(total / 2)

    local ok, monitors = pcall(hl.get_monitors)
    if not ok or not monitors then
        print("[Dynamic WS] ERROR: hl.get_monitors() failed or returned nil")
        return
    end

    print("[Dynamic WS] Found " .. #monitors .. " monitors (raw order from API):")

    for i, m in ipairs(monitors) do
        print(string.format("[Dynamic WS] #%d → name='%s' id=%s x=%s focused=%s",
            i, m.name or "nil", m.id or "nil", m.x or "nil", tostring(m.focused)))
    end

    if #monitors == 0 then
        print("[Dynamic WS] No monitors detected")
        return
    end

    -- SMART SORT: prefer real .x when it looks valid, otherwise fall back to monitor ID
    local function getSortKey(m)
        if m.x and m.x >= 0 then
            return m.x          -- use real X position when it's sensible
        else
            return (m.id or 9999)  -- fallback to ID (0 = left, 1 = right in your case)
        end
    end

    table.sort(monitors, function(a, b)
        return getSortKey(a) < getSortKey(b)
    end)

    print("[Dynamic WS] After smart sort:")
    for i, m in ipairs(monitors) do
        print(string.format("[Dynamic WS]   Sorted #%d → name=%s  (key=%s)", i, m.name or "nil", getSortKey(m)))
    end

    local left  = monitors[1].name
    local right = monitors[2] and monitors[2].name or left

    print(string.format("[Dynamic WS] %d workspaces → Left:%s (1-%d) | Right:%s (%d-%d)",
                        total, left, half, right, half+1, total))

    -- First half → left monitor
    for i = 1, half do
        print(string.format("[Dynamic WS]   → workspace %d → %s", i, left))
        hl.workspace_rule({
            workspace = i,
            monitor   = left,
            persistent = true,
            default   = (i == 1)
        })
    end

    -- Second half → right monitor
    for i = half + 1, total do
        print(string.format("[Dynamic WS]   → workspace %d → %s", i, right))
        hl.workspace_rule({
            workspace = i,
            monitor   = right,
            persistent = true
        })
    end
end

-- Auto-run when Hyprland starts and when monitors change
hl.on("hyprland.start", setup_dynamic_workspaces)
hl.on("monitor.added", setup_dynamic_workspaces)
hl.on("monitor.removed", setup_dynamic_workspaces)

setup_dynamic_workspaces()

print("[Dynamic WS] Event handlers registered")

