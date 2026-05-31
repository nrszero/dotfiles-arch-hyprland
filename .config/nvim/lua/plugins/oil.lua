return {
    'stevearc/oil.nvim',
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        require("oil").setup({
            -- This tells Oil to completely replace netrw
            default_file_explorer = true,
        })
        
        -- Replace your old <leader>e bind with Oil
        vim.keymap.set("n", "<leader>e", "<CMD>Oil<CR>", { desc = "Open Oil" })
    end
}
