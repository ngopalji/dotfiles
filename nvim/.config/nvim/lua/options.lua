require "nvchad.options"

-- Indentation settings
local o = vim.o
o.tabstop = 4        -- A tab is 4 spaces
o.shiftwidth = 4     -- Indent by 4 spaces
o.softtabstop = 4    -- Tab key inserts 4 spaces
o.expandtab = true   -- Use spaces instead of tabs

-- Auto-reload files when changed externally
o.autoread = true    -- Auto-reload files when changed outside vim
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  command = "if mode() != 'c' | checktime | endif",
})

-- Notification when file changes
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  callback = function()
    vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.INFO)
  end,
})

o.cursorline = true      -- Highlight the current line
o.cursorlineopt = 'both' -- Highlight both the line number and line

-- Disable line wrapping; scroll horizontally instead
o.wrap = false
o.sidescroll = 1
o.sidescrolloff = 8

-- Soft-wrap at word boundaries for markdown
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
  end,
})

-- Let the colorscheme win over LSP semantic tokens (default: semantic 125 >
-- treesitter 100). Without this, tsserver repaints JSX components as
-- function-blue regardless of the theme's @tag colors.
vim.hl.priorities.semantic_tokens = 95

-- Rounded borders on all floating windows that don't set their own
-- (LSP hover, signature help, diagnostics float, rename, etc.)
vim.o.winborder = "rounded"

-- Diff filler ("deleted lines" padding in side-by-side diffs): blank space
-- instead of ---- dashes, claude-code style
vim.opt.fillchars:append { diff = " " }
