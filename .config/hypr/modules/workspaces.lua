-- First half of workspaces → leftmost monitor
-- Second half → rightmost monitor

local function setup_dynamic_workspaces()
    local total = WORKSPACES or 6
    local half  = math.ceil(total / 2)

    for i = 1, half do
        hl.workspace_rule({
            workspace = i,
            monitor   = LEFT_MONITOR,
            persistent = true,
            default   = (i == 1)
        })
    end

    for i = half + 1, total do
        hl.workspace_rule({
            workspace = i,
            monitor   = RIGHT_MONITOR,
            persistent = true
        })
    end
end

hl.on("hyprland.start", setup_dynamic_workspaces)
hl.on("monitor.added", setup_dynamic_workspaces)
hl.on("monitor.removed", setup_dynamic_workspaces)

setup_dynamic_workspaces()
