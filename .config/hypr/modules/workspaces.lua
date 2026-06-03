-- First half of workspaces → leftmost monitor
-- Second half → rightmost monitor

local function setup_dynamic_workspaces()
    local total = WORKSPACES or 6
    local half  = math.ceil(total / 2)
    print(string.format("[Dynamic WS] Using static monitors → Left:%s | Right:%s", LEFT_MONITOR, RIGHT_MONITOR))
  
    -- First half → left monitor
    for i = 1, half do
        print(string.format("[Dynamic WS]   → workspace %d → %s", i, LEFT_MONITOR))
        hl.workspace_rule({
            workspace = i,
            monitor   = LEFT_MONITOR,
            persistent = true,
            default   = (i == 1)
        })
    end

    -- Second half → right monitor
    for i = half + 1, total do
        print(string.format("[Dynamic WS]   → workspace %d → %s", i, RIGHT_MONITOR))
        hl.workspace_rule({
            workspace = i,
            monitor   = RIGHT_MONITOR,
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

