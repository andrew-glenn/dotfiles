local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
  return
end

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
local formatting = null_ls.builtins.formatting
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics

-- https://github.com/prettier-solidity/prettier-plugin-solidity
-- npm install --save-dev prettier prettier-plugin-solidity
local null_helpers = require('null-ls.helpers')

local cfn_lint = {
method = null_ls.methods.DIAGNOSTICS,
filetypes = {'yaml.cloudformation'},
generator = null_helpers.generator_factory({
command = "cfn-lint",
to_stdin = true,
to_stderr = true,
args = { "--format", "parseable", "-" },
format = "line",
check_exit_code = function(code)
return code == 0 or code == 255
end,
on_output = function(line, params)
local row, col, end_row, end_col, code, message = line:match(":(%d+):(%d+):(%d+):(%d+):(.*):(.*)")
local severity = null_helpers.diagnostics.severities['error']

if message == nil then
return nil
end

if vim.startswith(code, "E") then
severity = null_helpers.diagnostics.severities['error']
elseif vim.startswith(code, "W") then
severity = null_helpers.diagnostics.severities['warning']
else
severity = null_helpers.diagnostics.severities['information']
end

return {
message = message,
code = code,
row = row,
col = col,
end_col = end_col,
end_row = end_row,
severity = severity,
source = "cfn-lint",
}
end,
})
}



null_ls.setup {
  debug = false,
  sources = {
    formatting.prettier.with {
      extra_filetypes = { "toml", "solidity", "tsx", "ts" },
      extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
    },
    formatting.black.with { extra_args = { "--fast" } },
    formatting.stylua,
    cfn_lint
  },
}

