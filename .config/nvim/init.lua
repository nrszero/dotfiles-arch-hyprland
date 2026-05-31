require("config.lazy")

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.wo.number = true
vim.opt.clipboard = "unnamedplus"

---KEYMAPS---

---THEME---
vim.opt.termguicolors = true
--vim.cmd.colorscheme "tokyonight-night"
vim.cmd.colorscheme "modus"
vim.api.nvim_set_hl(0, 'Normal', {bg = 'None'})
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })


