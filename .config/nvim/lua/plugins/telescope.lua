return {
    'nvim-telescope/telescope.nvim', version = '*',
    dependencies = {
        'nvim-lua/plenary.nvim',
        -- optional but recommended
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
    },

    config = function()
        local builtin = require("telescope.builtin")
        vim.keymap.set('n', '<leader>ff', function ()
            builtin.find_files({ hidden = true })
        end, { desc = 'Find Files' })
        vim.keymap.set('n', '<leader>fg', function()
            builtin.live_grep({
                additional_args = function()
                    return { "--hidden", "--glob=!.git/" }
                end
            })
        end, { desc = 'Live Grep (Hidden)' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Buffers' })
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help Tags' })
    end
}
