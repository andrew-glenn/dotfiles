-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.opt.relativenumber = false
vim.opt.cursorline = true
vim.cmd([[hi CursorLineNr ctermfg=Yellow guifg=#f5ee27 gui=bold]])
vim.cmd([[hi clear CursorLine]])
vim.cmd([[hi CursorLine cterm=underline gui=underline]])
--vim.api.nvim_set_hl(0, "CursorLine", { ctermbg = "Red", force = true })
-- Optional: link CursorLineNr to CursorLine background
--vim.api.nvim_set_hl(0, "CursorLineNr", { ctermbg = "Red" })

--vim.highlight
--vim.g.moonflyCursorColor = true
--highlight(0, "CursorLine", { bg = grey62 })
