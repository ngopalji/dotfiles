-- Same structure as https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "gopbeans",

	-- extra base46 integrations to compile (loaded in configs/diffview.lua)
	integrations = { "diffview" },

	hl_override = {
		-- lighter grey so comments stay readable on diff backgrounds too
		Comment = { italic = true, fg = "#9a9a9a" },
		["@comment"] = { italic = true, fg = "#9a9a9a" },
		-- Blue highlight for visual mode
		Visual = { bg = "#3366cc", bold = true },
		VisualNOS = { bg = "#3366cc" },
		-- Green highlight for copy flash (yank)
		IncSearch = { bg = "#50fa7b", fg = "#282a36" },
	},
}

M.ui = {
	telescope = { style = "bordered" },
}

return M
