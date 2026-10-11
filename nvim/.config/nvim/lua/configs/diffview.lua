local diffview = require("diffview")

diffview.setup({
  -- Enhanced diff highlighting (uses your theme's colors)
  enhanced_diff_hl = true,

  -- Use icons
  use_icons = true,

  keymaps = {
    -- Enter opens the file's diff AND moves the cursor into it
    -- (default select_entry opens it but leaves focus in the panel)
    file_panel = {
      { "n", "<cr>", require("diffview.actions").focus_entry, { desc = "Open diff and focus it" } },
    },
    file_history_panel = {
      { "n", "<cr>", require("diffview.actions").focus_entry, { desc = "Open diff and focus it" } },
    },
  },

  hooks = {
    -- Diff windows open with everything folded (foldmethod=diff);
    -- start fully unfolded — zc/za still work to fold manually.
    diff_buf_win_enter = function(bufnr, winid)
      vim.wo[winid].foldlevel = 99
      -- gd / gr / gh inside the diff, proxied through the working-tree file
      require("configs.diffview_lsp").attach(bufnr)
    end,
  },
})

-- <C-o> returns to the diff after a gd from it
require("configs.diffview_lsp").setup()

-- Load base46's compiled diffview highlights (deleted-line red, dim filler).
-- Must run AFTER setup: enhanced_diff_hl derives its own versions of these
-- groups during setup and would overwrite ours. Re-apply on ColorScheme too,
-- since diffview re-derives them on that event.
local function load_diffview_hl()
  pcall(dofile, vim.g.base46_cache .. "diffview")
end
load_diffview_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("GopbeansDiffviewHl", { clear = true }),
  callback = function()
    vim.schedule(load_diffview_hl)
  end,
})
