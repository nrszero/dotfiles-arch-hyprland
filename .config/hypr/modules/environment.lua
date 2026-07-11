-- Determine the GPU topology of the current machine
local function get_gpu_layout()
    -- Query all VGA and 3D controllers
    local handle = io.popen("lspci | grep -iE 'vga|3d'")
    if not handle then return "unknown" end
    
    local result = handle:read("*a"):lower()
    handle:close()

    local has_nvidia = result:match("nvidia")
    local has_intel = result:match("intel")
    local has_amd = result:match("amd") or result:match("radeon")

    -- If NVIDIA exists alongside an integrated GPU, it's a hybrid system
    if has_nvidia and (has_intel or has_amd) then
        return "hybrid"
    -- If only NVIDIA is present, it's a dedicated desktop setup
    elseif has_nvidia then
        return "nvidia_dedicated"
    else
        return "other"
    end
end

local gpu_layout = get_gpu_layout()

if gpu_layout == "nvidia_dedicated" then
    hl.config({
        env = {
            hl.env("LIBVA_DRIVER_NAME", "nvidia"),
            hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia"),
            hl.env("GBM_BACKEND", "nvidia-drm"),
        }
    })
    print("-> Dedicated NVIDIA GPU layout detected. Environment variables injected.")
else
    print("-> Hybrid or non-NVIDIA layout detected (" .. gpu_layout .. "). Skipping proprietary Wayland variables.")
end

hl.env("XCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_SIZE", 24)
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("GTK_THEME", "Adwaita-dark")
hl.env("EDITOR", "nvim")
