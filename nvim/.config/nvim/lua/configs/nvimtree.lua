local options = {
  hijack_cursor = false,
  disable_netrw = true,
  hijack_netrw = true,
  hijack_unnamed_buffer_when_opening = false,
  update_focused_file = {
    enable = true,
    update_root = false,
  },
  view = {
    width = 35,
    side = "left",
    preserve_window_proportions = true,
  },
  renderer = {
    highlight_git = true,
    icons = {
      show = {
        git = true,
      },
    },
  },
  -- Drop nvim-tree's C-hjkl mappings so window navigation works from the tree
  on_attach = function(bufnr)
    local api = require("nvim-tree.api")

    -- Default mappings
    api.config.mappings.default_on_attach(bufnr)

    -- Safely remove conflicting mappings if they exist
    local function safe_del(mode, lhs, opts)
      pcall(vim.keymap.del, mode, lhs, opts)
    end

    safe_del("n", "<C-k>", { buffer = bufnr })
    safe_del("n", "<C-h>", { buffer = bufnr })
    safe_del("n", "<C-l>", { buffer = bufnr })
    safe_del("n", "<C-j>", { buffer = bufnr })

    -- Keep useful mappings but with different keys
    vim.keymap.set("n", "?", api.tree.toggle_help, { buffer = bufnr, desc = "Help" })
    vim.keymap.set("n", "I", api.tree.toggle_gitignore_filter, { buffer = bufnr, desc = "Toggle gitignore" })
    vim.keymap.set("n", "g.", api.tree.toggle_hidden_filter, { buffer = bufnr, desc = "Toggle hidden files" })

    -- Shift+hjkl moves 5 like everywhere else (replaces nvim-tree's H/J/K/L)
    for _, k in ipairs { "h", "j", "k", "l" } do
      vim.keymap.set("n", k:upper(), "5" .. k, { buffer = bufnr, desc = "Move 5 " .. k })
    end

    -- <C-v>/<C-x> (defaults) split inside nvim; <M-v>/<M-x> open in a new herdr (or tmux) pane
    local pane = require "configs.pane_open"
    vim.keymap.set("n", "<M-v>", pane.tree "right", { buffer = bufnr, desc = "Open: herdr/tmux pane right" })
    vim.keymap.set("n", "<M-x>", pane.tree "down", { buffer = bufnr, desc = "Open: herdr/tmux pane down" })
  end,
}

return options