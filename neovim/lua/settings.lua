--[[
______           _        _____              __ _
| ___ \         (_)      /  __ \            / _(_)
| |_/ / __ _ ___ _  ___  | /  \/ ___  _ __ | |_ _  __ _
| ___ \/ _` / __| |/ __| | |    / _ \| '_ \|  _| |/ _` |
| |_/ / (_| \__ \ | (__  | \__/\ (_) | | | | | | | (_| |
\____/ \__,_|___/_|\___|  \____/\___/|_| |_|_| |_|\__, |
                                                   __/ |
                                                  |___/
--]]

local settings = {
  backup = false,                          -- creates a backup file
  clipboard = "unnamedplus",               -- allows neovim to access the system clipboard
  cmdheight = 2,                           -- more space in the neovim command line for displaying messages
  completeopt = { "menuone", "noselect" }, -- mostly just for cmp
  conceallevel = 0,                        -- so that `` is visible in markdown files
  -- colorcolumn = "90",
  fileencoding = "utf-8",                  -- the encoding written to a file
  hlsearch = true,                         -- highlight all matches on previous search pattern
  ignorecase = true,                       -- ignore case in search patterns
  mouse = "a",                             -- allow the mouse to be used in neovim
  pumheight = 10,                          -- pop up menu height
  showmode = false,                        -- we don't need to see things like -- INSERT -- anymore
  showtabline = 2,                         -- always show tabs
  smartcase = true,                        -- smart case
  smartindent = true,                      -- make indenting smarter again
  splitbelow = true,                       -- force all horizontal splits to go below current window
  splitright = true,                       -- force all vertical splits to go to the right of current window
  swapfile = false,                        -- creates a swapfile
  termguicolors = true,                    -- set term gui colors (most terminals support this)
  timeoutlen = 400,                        -- time to wait for a mapped sequence to complete (in milliseconds)
  undofile = true,                         -- enable persistent undo
  updatetime = 300,                        -- faster completion (4000ms default)
  writebackup = false,                     -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
  expandtab = true,                        -- convert tabs to spaces
  shiftwidth = 2,                          -- the number of spaces inserted for each indentation
  tabstop = 2,                             -- insert 2 spaces for a tab
  cursorline = true,                       -- highlight the current line
  number = true,                           -- set numbered lines
  relativenumber = false,                  -- set relative numbered lines
  numberwidth = 4,                         -- set number column width to 2 {default 4}
  signcolumn = "yes",                      -- always show the sign column, otherwise it would shift the text each time
  wrap = false,                            -- display lines as one long line
  scrolloff = 8,                           -- is one of my fav
  sidescrolloff = 8,
}
vim.opt.shortmess:append "c"
vim.g.mapleader = ','
-- better session options
vim.o.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal"

vim.cmd([[
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_enter = 1
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '·'
let g:gitgutter_sign_added = '|'
let g:gitgutter_sign_modified = '|'
let g:gitgutter_sign_removed = '|'
let g:gitgutter_sign_modified_removed = '|'
let g:go_fillstruct_mode = 'gopls'
let g:terraform_fmt_on_save=1
let g:terraform_aligh=1
au! BufNewFile,BufReadPost *.template.{yaml} set filetype=yaml.cloudformation
au! BufNewFile,BufReadPost *.template.json set filetype=json.cloudformation
highlight GitGutterAdd ctermfg=2
highlight GitGutterChange ctermfg=3
highlight GitGutterDelete ctermfg=1
highlight GitGutterChangeDelete ctermfg=4
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
autocmd BufWritePre *.go :silent! lua require('go.format').gofmt()
]])
-- iterate through the options and set them
for key, value in pairs(settings) do
  vim.opt[key] = value
end

