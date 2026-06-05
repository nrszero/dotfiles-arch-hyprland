-- Check if an Nvidia GPU is present
local function check_nvidia()
    -- Execute the lspci command and capture the output stream
    local handle = io.popen("lspci | grep -iE 'vga|3d' | grep -i nvidia")
    if handle then
        local result = handle:read("*a")
        handle:close()

        -- If the result string is not empty, an NVIDIA card was found
        return result ~= ""
    end
end

local is_nvidia = check_nvidia()

if is_nvidia then
    hl.config({
        env = {
            hl.env("LIBVA_DRIVER_NAME", "nvidia"),
            hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia"),
            hl.env("GBM_BACKEND", "nvidia-drm"),
        }
    })
    print("-> NVIDIA GPU detected natively. Environment variables injected.")
else
    print("-> Non-NVIDIA GPU detected. Skipping proprietary Wayland variables.")
end

hl.env("XCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_SIZE", 24)
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("GTK_THEME", "Adwaita-dark")
hl.env("EDITOR", "nvim")
