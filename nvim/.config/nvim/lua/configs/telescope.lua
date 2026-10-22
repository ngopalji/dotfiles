local telescope = require "telescope"
local actions = require "telescope.actions"

-- Override NvChad's telescope config
telescope.setup {
  defaults = {
    prompt_prefix = " ",
    selection_caret = " ",
    sorting_strategy = "ascending",
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    layout_config = {
      horizontal = {
        prompt_position = "top",
        preview_width = 0.55,
      },
      width = 0.87,
      height = 0.80,
    },
    mappings = {
      i = {
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        -- <C-v>/<C-x> (defaults) split inside nvim; <M-v>/<M-x> open in a new herdr (or tmux) pane
        ["<M-v>"] = require("configs.pane_open").telescope "right",
        ["<M-x>"] = require("configs.pane_open").telescope "down",
      },
      n = {
        ["<M-v>"] = require("configs.pane_open").telescope "right",
        ["<M-x>"] = require("configs.pane_open").telescope "down",
      },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
  },
}