local refactoring = require "refactoring"

refactoring.setup {
  prompt_func_return_type = {
    go = false,
    java = false,
    cpp = false,
    c = false,
    h = false,
    hpp = false,
    cxx = false,
  },
  prompt_func_param_type = {
    go = false,
    java = false,
    cpp = false,
    c = false,
    h = false,
    hpp = false,
    cxx = false,
  },
  printf_statements = {},
  print_var_statements = {},
}

-- Telescope integration for refactoring
vim.api.nvim_set_keymap(
  "v",
  "<leader>rr",
  "<Esc><cmd>lua require('telescope').extensions.refactoring.refactors()<CR>",
  { noremap = true }
)

-- Direct keymaps for common refactorings
vim.api.nvim_set_keymap("x", "<leader>re", ":Refactor extract ", { noremap = true })
vim.api.nvim_set_keymap("x", "<leader>rf", ":Refactor extract_to_file ", { noremap = true })
vim.api.nvim_set_keymap("x", "<leader>rv", ":Refactor extract_var ", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>ri", ":Refactor inline_var", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>rI", ":Refactor inline_func", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>rb", ":Refactor extract_block", { noremap = true })
vim.api.nvim_set_keymap("n", "<leader>rbf", ":Refactor extract_block_to_file", { noremap = true })