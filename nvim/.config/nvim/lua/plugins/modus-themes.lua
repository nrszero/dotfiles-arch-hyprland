return {
    "miikanissi/modus-themes.nvim",
    priority = 1000, -- Ensure it loads first
    config = function()
        -- 1. Configure the theme options
        require("modus-themes").setup({
            style = "vivendi", -- The dark theme
            transparent = true, -- Enable transparency
            hide_inactive_statusline = false, -- Optional: hide inactive statuslines
            line_nr_column_background = false, 
        })
    end,
}
