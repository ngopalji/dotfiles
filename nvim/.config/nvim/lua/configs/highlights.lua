-- Custom highlight overrides
local M = {}

M.setup = function()
  -- Apply custom highlights after theme loads
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      -- Blue highlight for visual mode with blend for transparency
      vim.api.nvim_set_hl(0, "Visual", { bg = "#2e5090", blend = 30 })
      vim.api.nvim_set_hl(0, "VisualNOS", { bg = "#2e5090", blend = 30 })
      
      -- Green highlight for yank (no transparency)
      vim.api.nvim_set_hl(0, "YankFlash", { bg = "#50fa7b", fg = "#1e1e1e" })

    end,
  })

  -- Immediately apply the highlights
  vim.api.nvim_set_hl(0, "Visual", { bg = "#2e5090", blend = 30 })
  vim.api.nvim_set_hl(0, "VisualNOS", { bg = "#2e5090", blend = 30 })
  vim.api.nvim_set_hl(0, "YankFlash", { bg = "#50fa7b", fg = "#1e1e1e" })

  
  -- Green flash after yanking (copying)
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
    pattern = "*",
    callback = function()
      vim.highlight.on_yank({ higroup = "YankFlash", timeout = 300 })
    end,
  })
end

return M